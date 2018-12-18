defmodule Deduplication.V2.Match do
  @moduledoc false

  use Confex, otp_app: :deduplication

  require Logger
  import Core.AuditLogs, only: [create_audit_logs: 1]
  import Ecto.Query

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.Repo
  alias Deduplication.V2.CandidatesDistance
  alias Deduplication.V2.Model
  alias Ecto.UUID

  @deduplication_client Application.get_env(:deduplication, :producer)
  @py_weight Application.get_env(:deduplication, :py_weight)

  def deduplicate_person(limit, offset) do
    persons = Model.get_unverified_persons(limit, offset)

    persons
    |> Task.async_stream(
      fn person ->
        with %Person{} <- person do
          candidates =
            person
            |> Model.get_candidates()
            |> match_candidates(person)

          {person, candidates}
        end
      end,
      timeout: 300_000
    )
    |> Model.async_stream_filter()
    |> set_merge_verified()

    Enum.count(persons)
  end

  def set_merge_verified(persons_candidates) do
    system_user_id = Confex.fetch_env!(:core, :system_user)

    {:ok, _} =
      Repo.transaction(fn ->
        Enum.each(persons_candidates, fn {person, candidates} ->
          candidates_ids = Enum.map(candidates, fn candidate -> candidate[:candidate].id end)

          merge_candidates(person.id, candidates, system_user_id)
          makr_persons_verified(person, candidates_ids, system_user_id)
        end)
      end)
  end

  def match_candidates(candidates, person) do
    config = config()
    system_user_id = Confex.fetch_env!(:core, :system_user)
    score = String.to_float(config[:score])
    kafka_score = String.to_float(config[:kafka_score])
    normalized_person = Model.normalize_person(person)

    candidates
    |> Task.async_stream(fn candidate ->
      normalized_candidate = Model.normalize_person(candidate)

      weigth_map =
        normalized_person
        |> CandidatesDistance.levenshtein_weight(normalized_candidate)
        |> CandidatesDistance.finalize_weight()

      pair_weight = @py_weight.weight(weigth_map)

      cond do
        pair_weight >= kafka_score ->
          @deduplication_client.publish_person_merged_event(
            candidate.id,
            system_user_id
          )

          %{candidate: candidate, weight: pair_weight, matrix: weigth_map}

        pair_weight >= score ->
          %{candidate: candidate, weight: pair_weight, matrix: weigth_map}

        true ->
          :skip
      end
    end)
    |> Model.async_stream_filter()
  end

  def merge_candidates(person_id, candidates, system_user_id) do
    merge_candidates =
      candidates
      |> Task.async_stream(fn %{candidate: candidate, weight: score, matrix: weigth_map} ->
        %{
          id: UUID.generate(),
          master_person_id: person_id,
          person_id: candidate.id,
          status: "NEW",
          config: weigth_map,
          details: %{score: score},
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now()
        }
      end)
      |> Model.async_stream_filter()

    Repo.insert_all(MergeCandidate, merge_candidates)
    log_insert(merge_candidates, system_user_id)
  end

  defp log_insert(merge_candidates, system_user_id) do
    changes =
      merge_candidates
      |> Task.async_stream(fn mc ->
        %{
          actor_id: system_user_id,
          resource: "merge_candidates",
          resource_id: mc[:id],
          changeset: mc
        }
      end)
      |> Model.async_stream_filter()

    create_audit_logs(changes)
  end

  defp makr_persons_verified(person, candidates_ids, system_user_id) do
    person_query =
      from(p in Person,
        where: p.id == ^person.id,
        update: [
          set: [
            merged_ids: ^((person.merged_ids || []) ++ candidates_ids),
            merge_verified: true,
            updated_by: ^system_user_id
          ]
        ]
      )

    {1, _} = Repo.update_all(person_query, [])
  end
end
