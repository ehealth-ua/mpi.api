defmodule Core.ManualMerge do
  @moduledoc """
  Boundary module for manual merge functionality
  """

  alias Core.DeduplicationRepo
  alias Core.ManualMergeCandidate
  alias Core.ManualMergeRequest

  def create(%ManualMergeCandidate{} = merge_request, params, actor_id) when is_binary(actor_id) do
    merge_request
    |> ManualMergeCandidate.changeset(put_inserted_by(params, actor_id))
    |> insert_and_log(actor_id)
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

  defp put_inserted_by(params, actor_id), do: Map.put(params, :inserted_by, actor_id)

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
