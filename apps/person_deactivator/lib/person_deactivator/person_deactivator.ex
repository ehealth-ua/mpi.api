defmodule PersonDeactivator do
  @moduledoc """
  Deactivate persons according to day limit
  """
  require Logger
  use Confex, otp_app: :person_deactivator

  alias Core.MergeCandidate
  alias Core.MergeCandidates.API, as: MergeCandidatesAPI
  alias Core.MergedPair
  alias Core.Person
  alias Core.Persons.PersonsAPI
  alias Core.Repo

  @kafka_producer Application.get_env(:person_deactivator, :producer)
  @rpc_worker Application.get_env(:person_deactivator, :rpc_worker)

  def deactivate_person(merge_candidate, actor_id, reason) do
    merge_candidate
    |> get_merge_candidate_with_status()
    |> process_merge_candidates(actor_id, reason)
  end

  defp get_merge_candidate_with_status(%{master_person_id: master_person_id, merge_person_id: merge_person_id}),
    do: MergeCandidatesAPI.get_status_by_master_and_merge(master_person_id, merge_person_id)

  defp update_merge_candidate_status(id, status, actor_id),
    do: MergeCandidatesAPI.update_status_by_id(id, MergeCandidate.status(status), actor_id)

  defp process_merge_candidates(merge_candidate, actor_id, reason) do
    %{id: id, master_person_id: master_id, merge_person_id: candidate_id} = merge_candidate

    with {_, true} <- {:actual, merge_candidate[:actual?]},
         {_, {:ok, _}} <- {:declaration, @rpc_worker.run("ops", OPS.Rpc, :get_declaration, [%{person_id: master_id}])},
         :ok <- @kafka_producer.publish_declaration_deactivation_event(candidate_id, actor_id, reason),
         {:ok, _} <- Repo.insert(%MergedPair{id: id, master_person_id: master_id, merge_person_id: candidate_id}),
         {:ok, _} <- PersonsAPI.update(candidate_id, %{"status" => Person.status(:inactive)}, actor_id) do
      update_merge_candidate_status(id, :merged, actor_id)
    else
      {:actual, false} ->
        update_merge_candidate_status(id, :stale, actor_id)

      {:declaration, nil} ->
        update_merge_candidate_status(id, :declined, actor_id)
    end
  end
end
