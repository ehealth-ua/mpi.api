defmodule Core.ManualMerge do
  @moduledoc """
  Boundary module for manual merge functionality
  """
  use Confex, otp_app: :core

  import Core.Query, only: [apply_cursor: 2]
  import Ecto.Query, only: [order_by: 2, select: 3, where: 3, or_where: 3]

  alias Core.DeduplicationRepo
  alias Core.Filters.Base, as: BaseFilter
  alias Core.ManualMergeCandidate
  alias Core.ManualMergeRequest
  alias Core.Repo
  alias Ecto.UUID

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

  def create(%ManualMergeRequest{} = merge_request, params, actor_id) when is_binary(actor_id) do
    merge_request
    |> ManualMergeRequest.changeset(params)
    |> insert_and_log(actor_id)
  end

  def update(%{__struct__: struct} = entity, params, actor_id)
      when is_binary(actor_id) and struct in [ManualMergeCandidate, ManualMergeRequest] do
    entity
    |> struct.changeset(params)
    |> update_and_log(actor_id)
  end

  def get_by_id(schema, id), do: DeduplicationRepo.get(schema, id)

  def fetch_merge_request_by_id(id) do
    case get_by_id(ManualMergeRequest, id) do
      %ManualMergeRequest{} = request -> {:ok, request}
      nil -> {:error, {:not_found, "Manual Merge Request not found"}}
    end
  end

  def process_merge_request(id, status, actor_id, comment \\ nil) when is_binary(actor_id) do
    with {:ok, merge_request} <- fetch_merge_request_by_id(id),
         :ok <- validate_assignee(merge_request, actor_id),
         :ok <- validate_status_transition(merge_request, status) do
      DeduplicationRepo.transaction(fn ->
        with {:ok, merge_request} <- update(merge_request, %{status: status, comment: comment}, actor_id),
             merge_request <- DeduplicationRepo.preload(merge_request, [:manual_merge_candidate]),
             {:ok, manual_merge_candidate} <- process_merge_candidates(merge_request, actor_id),
             :ok <- deactivate_person(manual_merge_candidate) do
          person_references = [:documents, :phones]

          Repo.preload(
            merge_request,
            manual_merge_candidate: [merge_candidate: [person: person_references, master_person: person_references]]
          )
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
           {:ok, manual_merge_candidate} <- update(request.manual_merge_candidate, update_data, actor_id),
           :ok <- process_related_merge_candidates(request, actor_id) do
        {:ok, manual_merge_candidate}
      end
    else
      with {:ok, _} <- update(request.manual_merge_candidate, %{assignee_id: nil}, actor_id) do
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
    |> DeduplicationRepo.update_all(set: update_data)

    # ToDo: add audit log for SQL update

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

  defp deactivate_person(%ManualMergeCandidate{status: @status_merge} = candidate) do
    # ToDo: put into deactivation consumer
    :ok
  end

  defp deactivate_person(_), do: :ok

  # ToDo: Ecto.Trail doesn't support multi repos.
  # At now it possible log just in audit_log_mpi table
  defp insert_and_log(changeset, _actor_id) do
    DeduplicationRepo.insert(changeset)
  end

  # ToDo: Ecto.Trail doesn't support multi repos.
  # At now it possible log just in audit_log_mpi table
  defp update_and_log(changeset, _actor_id) do
    DeduplicationRepo.update(changeset)
  end

  def search_manual_merge_requests([_ | _] = filter, order_by \\ [], cursor \\ nil) do
    person_references = [:documents, :phones]

    manual_merge_requests =
      ManualMergeRequest
      |> BaseFilter.filter(filter)
      |> apply_cursor(cursor)
      |> order_by(^order_by)
      |> DeduplicationRepo.all()
      |> DeduplicationRepo.preload(:manual_merge_candidate)
      |> Repo.preload(
        manual_merge_candidate: [merge_candidate: [person: person_references, master_person: person_references]]
      )

    {:ok, manual_merge_requests}
  end
end
