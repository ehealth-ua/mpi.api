defmodule MPI.Deduplication.Match do
  @moduledoc false

  require Logger

  import Ecto.Query

  alias MPI.Repo
  alias MPI.Person
  alias MPI.MergeCandidate
  alias Ecto.UUID
  alias Confex.Resolver

  use Confex, otp_app: :mpi

  def run do
    Logger.info("Starting to look for duplicates...")
    config = config()

    depth = -config[:depth]
    deduplication_score = String.to_float(config[:score])
    comparison_fields = config[:fields]

    candidates_query =
      from p in Person,
        left_join: mc in MergeCandidate, on: mc.person_id == p.id,
        where: p.inserted_at >= datetime_add(^DateTime.utc_now(), ^depth, "day"),
        where: is_nil(mc.id),
        order_by: [desc: :inserted_at]

    persons_query =
      from p in Person,
        left_join: mc in MergeCandidate, on: mc.person_id == p.id,
        where: is_nil(mc.id),
        order_by: [desc: :inserted_at]

    candidates = Repo.all(candidates_query)
    persons = Repo.all(persons_query)

    pairs = find_duplicates candidates, persons, fn candidate, person ->
      match_score(candidate, person, comparison_fields) >= deduplication_score
    end

    if length(pairs) > 0 do
      short_pairs = Enum.map(pairs, &{elem(&1, 0).id, elem(&1, 0).id})
      Logger.info(
        "Found duplicates. Will insert the following {master_person_id, person_id} pairs: #{inspect short_pairs}"
      )

      merge_candidates =
        Enum.map pairs, fn {master_person, person} ->
          %{
            id: UUID.generate(),
            master_person_id: master_person.id,
            person_id: person.id,
            status: "NEW",
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }
        end

      Repo.insert_all(MergeCandidate, merge_candidates)

      Enum.each config[:subscribers], fn subscriber ->
        url = Resolver.resolve!(subscriber)

        HTTPoison.post!(url, "", [{"Content-Type", "application/json"}])
      end
    else
      Logger.info("Found no duplicates.")
    end
  end

  def find_duplicates(candidates, persons, comparison_function) do
    candidate_is_duplicate? = fn person, acc ->
      Enum.any? acc, fn {_master_person, dup_person} -> dup_person == person end
    end

    pair_already_exists? = fn person1, person2, acc ->
      Enum.any? acc, &(&1 == {person1, person2})
    end

    Enum.reduce candidates, [], fn candidate, acc ->
      matching_persons =
        persons
        |> Enum.reject(fn person ->
             person == candidate ||
             candidate_is_duplicate?.(person, acc) ||
             pair_already_exists?.(person, candidate, acc)
           end)
        |> Enum.filter(fn person -> comparison_function.(candidate, person) end)
        |> Enum.map(fn person -> {candidate, person} end)

      matching_persons ++ acc
    end
  end

  def match_score(candidate, person, comparison_fields) do
    matched? = fn field_name, candidate_field, person_field ->
      case field_name do
        :documents ->
          find_passport = &(&1["type"] == "PASSPORT")

          passport1 = Enum.find(candidate_field, find_passport)
          passport2 = Enum.find(person_field, find_passport)

          if passport1 == passport2, do: :match, else: :no_match
        :phones ->
          common_phones =
            for phone1 <- candidate_field,
                phone2 <- person_field,
                phone1["number"] == phone2["number"],
            do: true

          if length(common_phones), do: :match, else: :no_match
        _ ->
          if candidate_field == person_field, do: :match, else: :no_match
      end
    end

    result =
      Enum.reduce comparison_fields, 0, fn {field_name, coeficients}, score ->
        candidate_field = Map.get(candidate, field_name)
        person_field = Map.get(person, field_name)

        score + coeficients[matched?.(field_name, candidate_field, person_field)]
      end

    Float.round(result, 2)
  end
end
