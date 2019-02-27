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

    @kafka_producer.publish_person_deactivation_event(candidates, system_user_id, @reason)
  end

  def get_merge_candidates(score, batch_size) do
    MergeCandidate
    |> select([m], %{id: m.id, master_person_id: m.master_person_id, merge_person_id: m.person_id})
    |> where([m], m.status == ^MergeCandidate.status(:new) and m.score >= ^score)
    |> limit(^batch_size)
    |> Repo.all()
  end
end
