defmodule PersonDeactivator do
  @moduledoc """
  Deactivate persons according to day limit
  """
  require Logger
  use Confex, otp_app: :person_deactivator
  import Ecto.Query

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.Repo
  alias Ecto.Multi

  @status_inactive Person.status(:inactive)
  @deduplication_client Application.get_env(:person_deactivator, :producer)

  def deactivate_persons(candidates, actor_id) do
    candidates
    |> deactivate_candidates_declarations(actor_id)
    |> deactivate_candidates(actor_id)
  end

  defp deactivate_candidates_declarations(merge_candidates, actor_id) do
    Enum.each(merge_candidates, fn %{person_id: person_id} ->
      @deduplication_client.publish_person_merged_event(person_id, actor_id)
    end)

    merge_candidates
  end

  defp deactivate_candidates(candidates, actor_id) do
    person_ids = Enum.map(candidates, &Map.get(&1, :person_id))
    merge_candidates_ids = Enum.map(candidates, &Map.get(&1, :id))
    deactivate_persons_query = from(p in Person, where: p.id in ^MapSet.to_list(MapSet.new(person_ids)))
    merge_candidates_query = from(m in MergeCandidate, where: m.id in ^merge_candidates_ids)

    Multi.new()
    |> Multi.update_all(:deactivate_persons, deactivate_persons_query,
      set: [status: @status_inactive, updated_by: actor_id]
    )
    |> Multi.update_all(:merge_candates, merge_candidates_query, set: [status: MergeCandidate.status(:merged)])
    |> Repo.transaction()
  end
end
