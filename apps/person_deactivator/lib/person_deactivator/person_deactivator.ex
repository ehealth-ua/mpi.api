defmodule PersonDeactivator do
  @moduledoc """
  Deactivate persons according to day limit
  """
  use Confex, otp_app: :person_deactivator
  import Ecto.Query

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.Repo
  alias Ecto.Multi

  @deduplication_client Application.get_env(:person_deactivator, :producer)

  def deactivate_persons do
    config = config()
    score = String.to_float(config[:score])
    kafka_score = String.to_float(config[:kafka_score])
    batch_size = config[:batch_size]
    deactivation_limit = config[:deactivation_limit]
    deactivate_persons_batch(deactivation_limit, batch_size, score, kafka_score)
  end

  def deactivate_persons_batch(deactivation_count, _, _, _) when deactivation_count <= 0, do: :ok

  def deactivate_persons_batch(_, 0, _, _), do: :ok

  def deactivate_persons_batch(deactivation_count, batch_size, score, kafka_score) do
    system_user_id = Confex.fetch_env!(:core, :system_user)
    current_batch_size = min(deactivation_count, batch_size)
    merge_candidates = get_new_merge_candidates(score, current_batch_size)
    deactivate_candidates(system_user_id, merge_candidates)

    Enum.each(
      merge_candidates,
      fn
        %{person_id: merged_person_id, score: score} when score >= kafka_score ->
          @deduplication_client.publish_person_merged_event(merged_person_id, system_user_id)

        _ ->
          nil
      end
    )

    deactivate_persons_batch(deactivation_count - batch_size, batch_size, score, kafka_score)
  end

  def get_new_merge_candidates(score, batch_size) do
    MergeCandidate
    |> select([m], %{person_id: m.person_id, id: m.id, score: m.score})
    |> where([m], m.status == ^MergeCandidate.status(:new) and m.score >= ^score)
    |> limit(^batch_size)
    |> Repo.all()
  end

  def deactivate_candidates(system_user_id, candidate_ids) do
    person_ids = Enum.map(candidate_ids, &Map.get(&1, :person_id))
    merge_candidates_ids = Enum.map(candidate_ids, &Map.get(&1, :id))

    deactivate_persons_query =
      from(p in Person,
        where: p.id in ^person_ids
      )

    merge_candidates_query =
      from(m in MergeCandidate,
        where: m.id in ^merge_candidates_ids
      )

    {:ok, _} =
      Multi.new()
      |> Multi.update_all(:deactivate_persons, deactivate_persons_query,
        set: [status: Person.status(:inactive), updated_by: system_user_id]
      )
      |> Multi.update_all(:merge_candates, merge_candidates_query,
        set: [status: MergeCandidate.status(:merged)]
      )
      |> Repo.transaction()
  end
end
