defmodule MPI.Deduplication.Match do
  @moduledoc false

  use Confex, otp_app: :mpi

  require Logger
  import Ecto.Query
  import MPI.AuditLogs, only: [create_audit_logs: 1]

  alias MPI.Repo
  alias MPI.Person
  alias MPI.MergeCandidate
  alias Ecto.UUID
  alias Confex.Resolver
  alias Ecto.Multi

  @person_status_inactive Person.status(:inactive)

  def run do
    Logger.info("Starting to look for duplicates...")
    config = config()

    depth = -config[:depth]
    deduplication_score = String.to_float(config[:score])
    comparison_fields = config[:fields]

    candidates_query =
      from(
        p in Person,
        left_join: mc in MergeCandidate,
        on: mc.person_id == p.id,
        where: p.inserted_at >= datetime_add(^DateTime.utc_now(), ^depth, "day"),
        where: is_nil(mc.id),
        order_by: [desc: :inserted_at]
      )

    persons_query =
      from(
        p in Person,
        left_join: mc in MergeCandidate,
        on: mc.person_id == p.id,
        where: is_nil(mc.id),
        order_by: [desc: :inserted_at]
      )

    candidates = Repo.all(candidates_query)
    persons = Repo.all(persons_query)

    pairs =
      find_duplicates(candidates, persons, fn candidate, person ->
        {score, details} = match_score(candidate, person, comparison_fields)
        {score >= deduplication_score, details}
      end)

    if length(pairs) > 0 do
      short_pairs = Enum.map(pairs, &{elem(&1, 1).id, elem(&1, 2).id})

      Logger.info(
        "Found duplicates. Will insert the following {master_person_id, person_id} pairs: #{inspect(short_pairs)}"
      )

      merge_candidates =
        Enum.map(pairs, fn {{_, details}, master_person, person} ->
          %{
            id: UUID.generate(),
            master_person_id: master_person.id,
            person_id: person.id,
            status: "NEW",
            config: Map.take(Enum.into(config, %{}), [:fields, :score, :depth]),
            details: prepare_details(details),
            inserted_at: DateTime.utc_now(),
            updated_at: DateTime.utc_now()
          }
        end)

      stale_persons_query =
        from(p in Person, where: p.id in ^Enum.map(pairs, fn {_, _master_person, person} -> person.id end))

      system_user_id = Confex.fetch_env!(:mpi, :system_user)

      {:ok, _} =
        Multi.new()
        |> Multi.insert_all(:insert_candidates, MergeCandidate, merge_candidates, returning: true)
        |> Multi.update_all(:update_stale_persons, stale_persons_query, set: [status: @person_status_inactive])
        |> Multi.run(:log_inserts, &log_insert(&1.insert_candidates, system_user_id))
        |> Repo.transaction()

      Enum.each(config[:subscribers], fn subscriber ->
        url = Resolver.resolve!(subscriber)

        HTTPoison.post!(url, "", [{"Content-Type", "application/json"}])
      end)
    else
      Logger.info("Found no duplicates.")
    end
  end

  def find_duplicates(candidates, persons, comparison_function) do
    candidate_is_duplicate? = fn person, acc ->
      Enum.any?(acc, fn {_, _master_person, dup_person} -> dup_person == person end)
    end

    pair_already_exists? = fn person1, person2, acc ->
      Enum.any?(acc, fn {_, p1, p2} -> {p1, p2} == {person1, person2} end)
    end

    Enum.reduce(candidates, [], fn candidate, acc ->
      matching_persons =
        persons
        |> Enum.reject(fn person ->
          person == candidate || candidate_is_duplicate?.(person, acc) || pair_already_exists?.(person, candidate, acc)
        end)
        |> Enum.map(fn person -> {comparison_function.(candidate, person), candidate, person} end)
        |> Enum.filter(fn {{a, _}, _, _} -> a end)

      matching_persons ++ acc
    end)
  end

  def match_score(candidate, person, comparison_fields) do
    matched? = fn field_name, candidate_field, person_field ->
      if field_name == :documents || field_name == :phones do
        compare_lists(candidate_field, person_field)
      else
        if candidate_field == person_field, do: :match, else: :no_match
      end
    end

    {score, details} =
      Enum.reduce(comparison_fields, {0.0, %{}}, fn {field_name, coeficients}, {score, details} ->
        candidate_field = Map.get(candidate, field_name)
        person_field = Map.get(person, field_name)

        weight = coeficients[matched?.(field_name, candidate_field, person_field)]

        details =
          Map.put_new(details, field_name, %{
            candidate: candidate_field,
            person: person_field,
            weight: weight
          })

        {score + weight, details}
      end)

    {Float.round(score, 2), details}
  end

  defp normalize_keys(map) do
    for {key, value} <- map, into: %{}, do: {String.downcase(key), value}
  end

  def compare_lists([], []), do: :match

  def compare_lists(candidate_field, person_field) when is_list(candidate_field) and is_list(person_field) do
    candidate_field = Enum.map(candidate_field, &normalize_keys(&1))
    person_field = Enum.map(person_field, &normalize_keys(&1))

    common_items =
      for item1 <- candidate_field,
          item2 <- person_field,
          item1["number"] == item2["number"],
          item1["type"] == item2["type"],
          do: true

    if List.first(common_items), do: :match, else: :no_match
  end

  def compare_lists(nil, nil), do: :match
  def compare_lists(field, field), do: :match
  def compare_lists(_, _), do: :no_match

  defp log_insert({_, merge_candidates}, system_user_id) do
    changes =
      Enum.map(merge_candidates, fn mc ->
        %{
          actor_id: system_user_id,
          resource: "merge_candidates",
          resource_id: mc.id,
          changeset: sanitize_changeset(mc)
        }
      end)

    create_audit_logs(changes)
    {:ok, changes}
  end

  defp sanitize_changeset(merge_candidate) do
    merge_candidate
    |> Map.from_struct()
    |> Map.drop([:__meta__, :inserted_at, :updated_at, :master_person, :person])
  end

  defp prepare_details(details) do
    score =
      details
      |> Enum.reduce(0.0, fn {_a, b}, sum -> sum + b[:weight] end)
      |> Float.round(2)

    %{
      weights: details,
      score: score
    }
  end
end
