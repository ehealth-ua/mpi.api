defmodule MPIScheduler.Jobs.AutoMergePersonsDeactivator do
  @moduledoc false

  use Confex, otp_app: :mpi_scheduler
  import Ecto.Query
  alias Core.MergeCandidate
  alias Core.Repo
  require Logger

  @kafka_producer Application.get_env(:candidates_merger, :producer)
  @reason "AUTO_MERGE"

  def run do
    config = config()
    system_user_id = Confex.fetch_env!(:core, :system_user)
    candidates = get_merge_candidates(config[:score], config[:batch_size])

    if not Enum.empty?(candidates),
      do: @kafka_producer.publish_person_deactivation_event(candidates, system_user_id, @reason)
  end

  def get_merge_candidates(score, batch_size) do
    query =
      MergeCandidate
      |> select([m], %{id: m.id})
      |> where([m], m.status == ^MergeCandidate.status(:new) and m.score >= ^score)
      |> limit(^batch_size)

    {_, candidates} =
      Repo.update_all(
        join(MergeCandidate, :inner, [d], dr in subquery(query), dr.id == d.id),
        [set: [status: MergeCandidate.status(:in_process), updated_at: DateTime.utc_now()]],
        returning: [:id, :master_person_id, :person_id]
      )

    Enum.map(candidates, &%{id: &1.id, master_person_id: &1.master_person_id, merge_person_id: &1.person_id})
  end
end
