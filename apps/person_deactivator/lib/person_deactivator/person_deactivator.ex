defmodule PersonDeactivator do
  @moduledoc """
  Deactivate persons according to day limit
  """
  require Logger
  use Confex, otp_app: :person_deactivator
  import Ecto.Query

  alias Core.MergeCandidate
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

  defp get_merge_candidate_with_status(%{master_person_id: master_person_id, merge_person_id: merge_person_id}) do
    MergeCandidate
    |> select([m, mp, cp], %{
      id: m.id,
      master_person_id: mp.id,
      merge_person_id: cp.id,
      actual?: mp.updated_at < m.updated_at and cp.updated_at < m.updated_at
    })
    |> join(:inner, [m], mp in Person, m.master_person_id == mp.id)
    |> join(:inner, [m, mp], cp in Person, m.person_id == cp.id)
    |> where([m, mp, cp], m.master_person_id == ^master_person_id and m.person_id == ^merge_person_id)
    |> Repo.one()
  end

  defp update_merge_candidate(id, status, actor_id) do
    with {:ok, _} <-
           %MergeCandidate{id: id}
           |> MergeCandidate.changeset(%{status: MergeCandidate.status(status)})
           |> Repo.update_and_log(actor_id) do
      :ok
    end
  end

  defp process_merge_candidates(merge_candidate, actor_id, reason) do
    %{id: id, master_person_id: master_id, merge_person_id: candidate_id} = merge_candidate

    with {:actual, true} <- {:actual, merge_candidate[:actual?]},
         declaration <- @rpc_worker.run("ops", OPS.Rpc, :get_declaration, [%{person_id: master_id}]),
         {:declaration, {:ok, _}} <- {:declaration, declaration},
         :ok <- @kafka_producer.publish_declaration_deactivation_event(candidate_id, actor_id, reason),
         {:ok, _} <- Repo.insert(%MergedPair{id: id, master_person_id: master_id, merge_person_id: candidate_id}),
         {:ok, _} <- PersonsAPI.update(candidate_id, %{"status" => Person.status(:inactive)}, actor_id) do
      update_merge_candidate(id, :merged, actor_id)
    else
      {:actual, false} ->
        update_merge_candidate(id, :stale, actor_id)

      {:declaration, nil} ->
        update_merge_candidate(id, :declined, actor_id)
    end
  end
end
