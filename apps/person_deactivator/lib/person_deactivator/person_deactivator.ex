defmodule PersonDeactivator do
  @moduledoc """
  Deactivate persons according to day limit
  """
  use Confex, otp_app: :person_deactivator

  alias Core.MergeCandidate
  alias Core.MergeCandidates.API, as: MergeCandidatesAPI
  alias Core.MergedPair
  alias Core.Person
  alias Core.Persons.PersonsAPI
  alias Core.Repo
  alias PersonDeactivator.EventManager

  require Logger

  @kafka_producer Application.get_env(:person_deactivator, :producer)
  @rpc_worker Application.get_env(:person_deactivator, :rpc_worker)
  @declaration_active "active"
  @declaration_deactivated MergeCandidate.status(:deactivate_ready)

  def deactivate_person(master_id, candidate_id, actor_id, reason) do
    with {:ok, %MergeCandidate{}} <-
           master_id
           |> MergeCandidatesAPI.get_by_master_and_candidate(candidate_id)
           |> process_merge_candidate(actor_id, reason) do
      :ok
    end
  end

  defp process_merge_candidate(nil, _, _), do: {:ok, %MergeCandidate{}}

  defp process_merge_candidate(%MergeCandidate{} = mc, actor_id, reason) do
    with :gt <- DateTime.compare(mc.inserted_at, mc.master_person.updated_at),
         :gt <- DateTime.compare(mc.inserted_at, mc.person.updated_at) do
      deactivate_person_with_declaration(mc, actor_id, reason)
    else
      _ -> MergeCandidatesAPI.update_merge_candidate(mc, %{status: MergeCandidate.status(:stale)}, actor_id)
    end
  end

  defp deactivate_person_with_declaration(%MergeCandidate{status: @declaration_deactivated} = mc, actor_id, _),
    do: deactivate_candidate(mc, actor_id)

  defp deactivate_person_with_declaration(mc, actor_id, reason) do
    with nil <- mc.person.master_person,
         search_ops <- [person_id: mc.master_person.id, status: @declaration_active],
         {:ok, _} <- @rpc_worker.run("ops", OPS.Rpc, :get_declaration, [search_ops]),
         {:ok, _} <- deactivate_declaration(mc, actor_id, reason) do
      deactivate_candidate(mc, actor_id)
    else
      _ -> MergeCandidatesAPI.update_merge_candidate(mc, %{status: MergeCandidate.status(:declined)}, actor_id)
    end
  end

  defp deactivate_candidate(%MergeCandidate{id: id, master_person: master, person: candidate} = mc, actor_id) do
    status_merged = MergeCandidate.status(:merged)
    status_inactive = Person.status(:inactive)

    with {:ok, person} <-
           Repo.transaction(fn ->
             Repo.insert(%MergedPair{id: id, master_person_id: master.id, merge_person_id: candidate.id})
             {:ok, person} = PersonsAPI.update(candidate.id, %{"status" => Person.status(:inactive)}, actor_id)
             {:ok, _} = MergeCandidatesAPI.update_merge_candidate(mc, %{status: status_merged}, actor_id)
             person
           end) do
      person
      |> EventManager.new_event(actor_id, status_inactive)
      |> @kafka_producer.publish_to_event_manager()

      {:ok, person}
    end
  end

  defp deactivate_declaration(mc, actor_id, reason) do
    # Crash if ops declaration termination event was not published to kafka
    :ok = @kafka_producer.publish_declaration_deactivation_event(mc.person.id, actor_id, reason)
    MergeCandidatesAPI.update_merge_candidate(mc, %{status: @declaration_deactivated}, actor_id)
  end
end
