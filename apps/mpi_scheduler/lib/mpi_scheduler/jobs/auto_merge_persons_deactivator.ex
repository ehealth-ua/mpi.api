defmodule MPIScheduler.Jobs.AutoMergePersonsDeactivator do
  @moduledoc false

  use Confex, otp_app: :mpi_scheduler
  alias Core.MergeCandidate
  alias Core.MergeCandidates.API, as: MergeCandidatesAPI
  require Logger

  @kafka_producer Application.get_env(:candidates_merger, :producer)
  @reason "AUTO_MERGE"
  @in_process MergeCandidate.status(:in_process)

  def run do
    config = config()
    system_user_id = Confex.fetch_env!(:core, :system_user)
    candidates = get_merge_candidates(config[:score], config[:batch_size])

    unless Enum.empty?(candidates), do: push_merge_candidates(candidates, system_user_id)
  end

  def get_merge_candidates(score, batch_size), do: MergeCandidatesAPI.get_new_merge_candidates(score, batch_size)

  defp push_merge_candidates(candidates, system_user_id) do
    Enum.map(candidates, fn %MergeCandidate{} = candidate ->
      with :ok <- @kafka_producer.publish_person_deactivation_event(candidate, system_user_id, @reason) do
        MergeCandidatesAPI.update_merge_candidate(candidate, %{status: @in_process}, system_user_id)
      end
    end)
  end
end
