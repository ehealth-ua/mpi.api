defmodule PersonDeactivator do
  @moduledoc """
  Deactivate persons according to day limit
  """
  require Logger
  use Confex, otp_app: :person_deactivator

  alias Core.MergeCandidate
  alias Core.MergedPair
  alias Core.Person
  alias Core.Persons.PersonsAPI
  alias Core.Repo

  @status_inactive Person.status(:inactive)
  @kafka_producer Application.get_env(:person_deactivator, :producer)

  def deactivate_person(merge_candidate, actor_id, reason) do
    with %{id: id, master_person_id: master_id, merge_person_id: candidate_id} <- merge_candidate,
         :ok <- @kafka_producer.publish_declaration_deactivation_event(candidate_id, actor_id, reason),
         {:ok, _} <- Repo.insert(%MergedPair{id: id, master_person_id: master_id, merge_person_id: candidate_id}),
         {:ok, _} <- PersonsAPI.update(candidate_id, %{"status" => @status_inactive}, actor_id),
         {:ok, _} <-
           %MergeCandidate{id: id}
           |> MergeCandidate.changeset(%{status: MergeCandidate.status(:merged)})
           |> Repo.update_and_log(actor_id) do
      :ok
    end
  end
end
