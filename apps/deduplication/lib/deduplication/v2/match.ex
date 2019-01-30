defmodule Deduplication.V2.Match do
  @moduledoc false

  use Confex, otp_app: :deduplication

  require Logger
  import Core.AuditLogs, only: [create_audit_logs: 1]
  import Ecto.Query

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.Repo
  alias Core.VerifiedTs
  alias Deduplication.V2.CandidatesDistance
  alias Deduplication.V2.Model
  alias Ecto.UUID

  @py_weight Application.get_env(:deduplication, :py_weight)

  def deduplicate_persons(persons) do
    persons
    |> Enum.reduce(0, fn person, count ->
      with %Person{} <- person do
        candidates =
          person
          |> Model.get_candidates()
          |> match_candidates(person)

        if candidates == [] do
          :ok
        else
          system_user_id = Confex.fetch_env!(:core, :system_user)
          candidates_ids = Enum.map(candidates, & &1[:candidate].id)

          Repo.transaction(fn ->
            merge_candidates(person.id, candidates, system_user_id)
            put_merge_candidates(person, candidates_ids, system_user_id)
          end)
        end

        Model.unlock_person_after_verify(person.id)
        set_current_verified_ts(person.updated_at)
      end

      count + 1
    end)
  end

  def match_candidates(candidates, person) do
    config = config()
    score = String.to_float(config[:score])
    normalized_person = Model.normalize_person(person)

    candidates
    |> Task.async_stream(
      fn candidate ->
        normalized_candidate = Model.normalize_person(candidate)

        weight_map =
          normalized_person
          |> CandidatesDistance.levenshtein_weight(normalized_candidate)
          |> CandidatesDistance.finalize_weight()

        pair_weight = @py_weight.weight(weight_map)

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
          score: score
        }
      end)
      |> Model.async_stream_filter()

    Repo.insert_all(MergeCandidate, merge_candidates)
    log_insert(merge_candidates, system_user_id)
  end

  def log_insert(merge_candidates, system_user_id) do
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

  defp put_merge_candidates(person, candidates_ids, system_user_id) do
    merged_ids =
      (person.merged_ids || [])
      |> List.flatten(candidates_ids)
      |> MapSet.new()
      |> MapSet.to_list()

    person_query =
      from(p in Person,
        where: p.id == ^person.id,
        update: [set: [merged_ids: ^merged_ids, updated_by: ^system_user_id]]
      )

    {1, _} = Repo.update_all(person_query, [])
  end

  def set_current_verified_ts(updated_at) do
    query =
      from(p in VerifiedTs,
        where: p.id == ^0,
        update: [set: [inserted_at: ^DateTime.utc_now(), updated_at: ^updated_at]]
      )

    {row_updated, _} = Repo.update_all(query, [])
    true = row_updated in [0, 1]
  end
end
