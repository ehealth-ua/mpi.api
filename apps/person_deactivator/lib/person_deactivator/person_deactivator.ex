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
  alias Core.Repo

  @status_inactive Person.status(:inactive)
  @kafka_producer Application.get_env(:person_deactivator, :producer)

  def deactivate_persons(candidates, actor_id, reason) do
    candidates
    |> deactivate_candidates_declarations(actor_id, reason)
    |> deactivate_candidates(actor_id)
  end

  defp deactivate_candidates_declarations(merge_candidates, actor_id, reason) do
    Enum.each(merge_candidates, fn %{merge_person_id: person_id} ->
      @kafka_producer.publish_declaration_deactivation_event(person_id, actor_id, reason)
    end)

    merge_candidates
  end

  defp deactivate_candidates(candidates, actor_id) do
    merge_person_ids = Enum.map(candidates, & &1[:merge_person_id])
    merge_candidate_ids = Enum.map(candidates, & &1[:id])

    Repo.transaction(fn ->
      Repo.insert_all(
        MergedPair,
        Enum.map(candidates, &Map.merge(&1, %{inserted_at: DateTime.utc_now(), updated_at: DateTime.utc_now()}))
      )

      Person
      |> where([p], p.id in ^merge_person_ids)
      |> Repo.update_all(set: [status: @status_inactive, updated_by: actor_id, updated_at: DateTime.utc_now()])

      MergeCandidate
      |> where([m], m.id in ^merge_candidate_ids)
      |> Repo.update_all(set: [status: MergeCandidate.status(:merged), updated_at: DateTime.utc_now()])
    end)
  end
end
