defmodule Core.ManualMerge do
  @moduledoc """
  Boundary module for manual merge functionality
  """

  alias Core.DeduplicationRepo
  alias Core.ManualMergeCandidate
  alias Core.ManualMergeRequest
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
end
