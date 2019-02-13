defmodule Core.ManualMerge do
  @moduledoc """
  Boundary module for manual merge functionality
  """
  use Confex, otp_app: :core

  import Core.Query, only: [apply_cursor: 2]
  import Ecto.Query

  alias Core.Filters.Base, as: BaseFilter
  alias Core.{DeduplicationRepo, Repo}
  alias Core.{ManualMergeCandidate, ManualMergeRequest}
  alias Ecto.{Changeset, UUID}

  @status_new ManualMergeRequest.status(:new)
  @status_split ManualMergeRequest.status(:split)
  @status_merge ManualMergeRequest.status(:merge)
  @status_trash ManualMergeRequest.status(:trash)
  @status_postpone ManualMergeRequest.status(:postpone)
  @status_processed ManualMergeCandidate.status(:processed)
  @status_reason_auto_merge ManualMergeCandidate.status_reason(:auto_merge)

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
      with {:ok, merge_candidate} <- do_update(merge_candidate, merge_candidate_params, actor_id),
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

  def process_merge_request(id, status, actor_id, comment \\ nil) when is_binary(actor_id) do
    with {:ok, merge_request} <- fetch_merge_request_by_id(id),
         :ok <- validate_assignee(merge_request, actor_id),
         :ok <- validate_status_transition(merge_request, status) do
      DeduplicationRepo.transaction(fn ->
        with {:ok, merge_request} <- do_update(merge_request, %{status: status, comment: comment}, actor_id),
             merge_request <- DeduplicationRepo.preload(merge_request, [:manual_merge_candidate]),
             {:ok, manual_merge_candidate} <- process_merge_candidates(merge_request, actor_id) do
          merge_request
          |> Map.put(:manual_merge_candidate, manual_merge_candidate)
          |> preload_merge_request_associations()
        else
          {:error, reason} -> DeduplicationRepo.rollback(reason)
        end
      end)
    end
  end

  defp validate_assignee(%ManualMergeRequest{assignee_id: assignee_id}, assignee_id), do: :ok
  defp validate_assignee(_, _), do: {:error, {:forbidden, "Current client is not allowed to access this resource"}}

  defp validate_status_transition(%ManualMergeRequest{status: @status_new}, update_status)
       when update_status in [@status_split, @status_merge, @status_trash, @status_postpone],
       do: :ok

  defp validate_status_transition(%ManualMergeRequest{status: @status_postpone}, update_status)
       when update_status in [@status_split, @status_merge, @status_trash],
       do: :ok

  defp validate_status_transition(_, _), do: {:error, {:conflict, "Incorrect transition status"}}

  defp process_merge_candidates(%ManualMergeRequest{} = request, actor_id) do
    if quorum_obtained?(request) do
      with update_data <- %{status: @status_processed, decision: request.status, assignee_id: nil},
           {:ok, manual_merge_candidate} <- do_update(request.manual_merge_candidate, update_data, actor_id),
           :ok <- process_related_merge_candidates(request, actor_id) do
        {:ok, manual_merge_candidate}
      end
    else
      with {:ok, _} <- do_update(request.manual_merge_candidate, %{assignee_id: nil}, actor_id) do
        {:ok, nil}
      end
    end
  end

  defp process_related_merge_candidates(%ManualMergeRequest{status: @status_merge} = request, actor_id) do
    person_id = request.manual_merge_candidate.person_id

    update_data = [
      decision: @status_merge,
      status: @status_processed,
      status_reason: @status_reason_auto_merge,
      assignee_id: nil,
      updated_at: DateTime.utc_now()
    ]

    ManualMergeCandidate
    |> where([c], c.person_id == ^person_id)
    |> or_where([c], c.master_person_id == ^person_id)
    |> DeduplicationRepo.update_all_and_log([set: update_data], actor_id)

    :ok
  end

  defp process_related_merge_candidates(_, _), do: :ok

  defp quorum_obtained?(%ManualMergeRequest{manual_merge_candidate_id: candidate_id, status: status}) do
    requests =
      ManualMergeRequest
      |> select([m], count(m.id))
      |> where([m], m.manual_merge_candidate_id == ^candidate_id)
      |> where([m], m.status == ^status)
      |> DeduplicationRepo.one()

    config()[:quorum] <= requests
  end

  defp preload_merge_request_associations(merge_request) do
    person_references = [:documents, :phones]

    merge_request
    |> DeduplicationRepo.preload(:manual_merge_candidate)
    |> Repo.preload(
      manual_merge_candidate: [merge_candidate: [person: person_references, master_person: person_references]]
    )
  end

  # TODO: We need more meaningful name for this function
  defp do_update(%{__struct__: struct} = entity, params, actor_id)
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
