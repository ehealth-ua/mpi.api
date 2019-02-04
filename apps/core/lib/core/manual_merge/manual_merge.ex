defmodule Core.ManualMerge do
  @moduledoc """
  Boundary module for manual merge functionality
  """

  import Core.Query, only: [apply_cursor: 2]
  import Ecto.Query, only: [order_by: 2]

  alias Core.DeduplicationRepo
  alias Core.Filters.Base, as: BaseFilter
  alias Core.ManualMergeCandidate
  alias Core.ManualMergeRequest
  alias Core.Repo
  alias Ecto.UUID

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

  def process_merge_request(%ManualMergeRequest{} = merge_request, decision, actor_id) when is_binary(actor_id) do
    merge_request
    |> ManualMergeRequest.changeset(%{decision: decision})
    |> update_and_log(actor_id)
  end

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
