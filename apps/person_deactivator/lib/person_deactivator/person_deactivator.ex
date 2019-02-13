defmodule PersonDeactivator do
  @moduledoc """
  Deactivate persons according to day limit
  """
  require Logger
  use Confex, otp_app: :person_deactivator
  import Ecto.Query

  alias Core.ManualMergeCandidate
  alias Core.ManualMergeRequest
  alias Core.MergeCandidate
  alias Core.MergeCandidates.API, as: MergeCandidates
  alias Core.Person
  alias Core.Repo
  alias Ecto.Multi

  @status_merge ManualMergeRequest.status(:merge)
  @deduplication_client Application.get_env(:person_deactivator, :producer)

  def deactivate_persons do
    config = config()
    kafka_score = String.to_float(config[:kafka_score])
    batch_size = config[:batch_size]
    deactivation_limit = config[:deactivation_limit]
    system_user_id = Confex.fetch_env!(:core, :system_user)
    current_batch_size = min(deactivation_limit, batch_size)

    deactivate_persons_batch(0, current_batch_size, kafka_score, system_user_id)
  end

  def deactivate_persons(%ManualMergeCandidate{decision: @status_merge} = manual_merge_candidate, actor_id) do
    with %MergeCandidate{} = merge_candidate <- MergeCandidates.get_by_id(manual_merge_candidate.merge_candidate_id),
         {:ok, _} =
           [merge_candidate]
           |> deactivate_candidates_declarations(actor_id)
           |> deactivate_candidates(actor_id) do
      :ok
    else
      err -> {:error, "Cannot update Merge Candidate for Person deactivation with #{inspect(err)}}"}
    end
  end

  def deactivate_persons(_, _), do: :ok

  def deactivate_persons_batch(deactivated, batch_size, kafka_score, system_user_id) do
    merge_candidates = get_new_merge_candidates(kafka_score, batch_size)
    n = Enum.count(merge_candidates)

    {:ok, _} =
      merge_candidates
      |> deactivate_candidates_declarations(system_user_id)
      |> deactivate_candidates(system_user_id)

    if n > 0, do: deactivate_persons_batch(deactivated + n, batch_size, kafka_score, system_user_id), else: deactivated
  end

  def get_new_merge_candidates(score, batch_size) do
    MergeCandidate
    |> select([m], %{id: m.id, person_id: m.person_id})
    |> where([m], m.status == ^MergeCandidate.status(:new) and m.score >= ^score)
    |> limit(^batch_size)
    |> Repo.all()
  end

  def deactivate_candidates_declarations(merge_candidates, system_user_id) do
    Enum.each(merge_candidates, fn %{person_id: person_id} ->
      @deduplication_client.publish_person_merged_event(person_id, system_user_id)
    end)

    merge_candidates
  end

  def deactivate_candidates(candidates, system_user_id) do
    person_ids = Enum.map(candidates, &Map.get(&1, :person_id))
    merge_candidates_ids = Enum.map(candidates, &Map.get(&1, :id))
    deactivate_persons_query = from(p in Person, where: p.id in ^MapSet.to_list(MapSet.new(person_ids)))
    merge_candidates_query = from(m in MergeCandidate, where: m.id in ^merge_candidates_ids)

    Multi.new()
    |> Multi.update_all(:deactivate_persons, deactivate_persons_query,
      set: [status: Person.status(:inactive), updated_by: system_user_id]
    )
    |> Multi.update_all(:merge_candates, merge_candidates_query, set: [status: MergeCandidate.status(:merged)])
    |> Repo.transaction()
  end
end
