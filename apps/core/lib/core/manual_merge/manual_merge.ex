defmodule Core.ManualMerge do
  @moduledoc """
  Boundary module for manual merge functionality
  """
  use Confex, otp_app: :core

  import Core.AuditLogs, only: [create_audit_logs: 2]
  import Core.Query, only: [apply_cursor: 2]
  import Ecto.Query

  alias Core.Filters.Base, as: BaseFilter
  alias Core.{DeduplicationRepo, Repo}
  alias Core.{ManualMergeCandidate, ManualMergeRequest}
  alias Ecto.{Changeset, UUID}

  require Logger

  @status_new ManualMergeRequest.status(:new)
  @status_postpone ManualMergeRequest.status(:postpone)

  def new_candidate(merge_candidate) do
    %{
      id: UUID.generate(),
      status: ManualMergeCandidate.status(:new),
      person_id: merge_candidate.person_id,
      master_person_id: merge_candidate.master_person_id,
      merge_candidate_id: merge_candidate.id,
      inserted_at: DateTime.utc_now(),
      updated_at: DateTime.utc_now()
    }
  end

  def create_manual_merge_candidates([], _batch_size, _system_user_id) do
    :ok
  end

  def create_manual_merge_candidates(merge_candidates, batch_size, system_user_id) do
    Logger.info(fn -> "Trying to create `#{length(merge_candidates)}}` Manual Merge Candidates" end)

    merge_candidates
    |> Stream.map(&new_candidate/1)
    |> Stream.chunk_every(batch_size)
    |> Enum.each(fn manual_merge_candidates ->
      ManualMergeCandidate
      |> DeduplicationRepo.insert_all(manual_merge_candidates, on_conflict: :nothing)
      |> log_insert(manual_merge_candidates, system_user_id)
    end)
  end

  defp log_insert({inserted, _}, manual_merge_candidates, system_user_id) when inserted > 0 do
    changes =
      manual_merge_candidates
      |> Task.async_stream(fn candidate ->
        %{
          actor_id: system_user_id,
          resource: "manual_merge_candidates",
          resource_id: candidate[:id],
          changeset: candidate
        }
      end)
      |> Enum.reduce([], fn
        {:ok, v}, acc -> [v | acc]
        _, acc -> acc
      end)

    create_audit_logs(:deduplication, changes)
  end

  defp log_insert(_, _, _), do: :ok

  def search_manual_merge_requests([_ | _] = filter, order_by \\ [], cursor \\ nil) do
    manual_merge_requests =
      ManualMergeRequest
      |> BaseFilter.filter(filter)
      |> apply_cursor(cursor)
      |> order_by(^order_by)
      |> DeduplicationRepo.all()
      |> preload_merge_request_associations()

    {:ok, manual_merge_requests}
  end

  def get_by_id(schema, id), do: DeduplicationRepo.get(schema, id)

  def fetch_merge_request_by_id(id) do
    case get_by_id(ManualMergeRequest, id) do
      %ManualMergeRequest{} = request -> {:ok, request}
      nil -> {:error, {:not_found, "Manual Merge Request not found"}}
    end
  end

  def assign_merge_candidate(actor_id) do
    with {:ok, merge_candidate} <- get_eligible_merge_candidate(actor_id),
         {:ok, merge_request} <- do_assign_merge_candidate(merge_candidate, actor_id) do
      {:ok, preload_merge_request_associations(merge_request)}
    end
  end

  defp get_eligible_merge_candidate(actor_id) do
    ManualMergeCandidate
    |> where([c], c.status == @status_new and is_nil(c.assignee_id))
    |> join(:left, [c], r in assoc(c, :manual_merge_requests))
    |> group_by([c], c.id)
    |> having([_, r], fragment("every(?)", r.assignee_id != ^actor_id or is_nil(r.id)))
    |> select([c, r], {c, fragment("count(?) as request_count", r.id)})
    |> order_by(desc: fragment("request_count"))
    |> limit(1)
    |> DeduplicationRepo.one()
    |> case do
      {merge_candidate, _} -> {:ok, merge_candidate}
      nil -> {:error, {:not_found, "Eligible manual merge candidate not found"}}
    end
  end

  defp do_assign_merge_candidate(merge_candidate, actor_id) do
    merge_candidate_params = %{assignee_id: actor_id, updated_at: DateTime.utc_now()}

    DeduplicationRepo.transaction(fn ->
      with {:ok, merge_candidate} <- update_and_log(merge_candidate, merge_candidate_params, actor_id),
           {:ok, merge_request} <- create_merge_request(merge_candidate, actor_id) do
        merge_request
      else
        {:error, reason} -> DeduplicationRepo.rollback(reason)
      end
    end)
  end

  defp create_merge_request(merge_candidate, actor_id) do
    %ManualMergeRequest{}
    |> ManualMergeRequest.changeset(%{assignee_id: actor_id})
    |> Changeset.put_assoc(:manual_merge_candidate, merge_candidate)
    |> DeduplicationRepo.insert_and_log(actor_id)
  end

  def preload_merge_request_associations(merge_request) do
    person_references = [:documents, :phones, :addresses]

    merge_request
    |> DeduplicationRepo.preload(:manual_merge_candidate)
    |> Repo.preload(
      manual_merge_candidate: [merge_candidate: [person: person_references, master_person: person_references]]
    )
  end

  def update_and_log(%{__struct__: struct} = entity, params, actor_id)
      when is_binary(actor_id) and struct in [ManualMergeCandidate, ManualMergeRequest] do
    entity
    |> struct.changeset(params)
    |> DeduplicationRepo.update_and_log(actor_id)
  end

  def can_assign_new?(assignee_id) do
    postponed_limit = config()[:max_postponed_requests]

    merge_request_statuses =
      ManualMergeRequest
      |> where([m], m.status in [@status_new, @status_postpone])
      |> where([m], m.assignee_id == ^assignee_id)
      |> group_by([m], m.status)
      |> select([m], {m.status, count(m.id)})
      |> DeduplicationRepo.all()
      |> Enum.into(%{})

    cond do
      Map.has_key?(merge_request_statuses, @status_new) -> false
      Map.get(merge_request_statuses, @status_postpone, 0) >= postponed_limit -> false
      true -> true
    end
  end
end
