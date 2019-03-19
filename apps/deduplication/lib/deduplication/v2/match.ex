defmodule Deduplication.V2.Match do
  @moduledoc false

  use Confex, otp_app: :deduplication

  import Core.AuditLogs, only: [create_audit_logs: 2]

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.Repo
  alias Deduplication.V2.CandidatesDistance
  alias Deduplication.V2.Model
  alias Ecto.UUID

  require Logger

  def deduplicate_persons(persons) do
    persons
    |> Enum.reduce(0, fn %Person{} = person, count ->
      person
      |> Model.get_candidates()
      |> match_candidates(person)
      |> store_merge_candidates(person)

      count + 1
    end)
  end

  def store_merge_candidates([]), do: :ok

  def store_merge_candidates(candidates, person) do
    system_user_id = Confex.fetch_env!(:core, :system_user)

    Repo.transaction(fn ->
      merge_candidates(person.id, candidates, system_user_id)
      Model.unlock_person_after_verify(person.id)
    end)
  end

  def match_candidates(candidates, person) do
    config = config()
    score = config[:score]
    normalized_person = Model.normalize_person(person)

    candidates
    |> Task.async_stream(
      fn candidate ->
        normalized_candidate = Model.normalize_person(candidate)

        weight_map =
          normalized_person
          |> CandidatesDistance.levenshtein_weight(normalized_candidate)
          |> CandidatesDistance.finalize_weight()

        pair_weight = config()[:py_weight].weight(weight_map)

        if pair_weight >= score,
          do: %{candidate: candidate, weight: pair_weight, matrix: weight_map},
          else: :skip
      end,
      timeout: config[:weight_count_timeout]
    )
    |> Model.async_stream_filter()
  end

  def merge_candidates(person_id, candidates, system_user_id) do
    merge_candidates =
      candidates
      |> Task.async_stream(fn %{candidate: candidate, weight: score, matrix: weight_map} ->
        score = if is_integer(score), do: score / 1, else: score

        %{
          id: UUID.generate(),
          master_person_id: person_id,
          person_id: candidate.id,
          status: "NEW",
          config: weight_map,
          inserted_at: DateTime.utc_now(),
          updated_at: DateTime.utc_now(),
          score: score,
          details: Model.get_deduplication_details()
        }
      end)
      |> Model.async_stream_filter()

    Repo.insert_all(MergeCandidate, merge_candidates, on_conflict: :nothing)
    log_insert(merge_candidates, system_user_id)
    merge_candidates
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

    create_audit_logs(:mpi, changes)
  end
end
