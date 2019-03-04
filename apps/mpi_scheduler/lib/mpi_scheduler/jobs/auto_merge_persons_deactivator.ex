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

    unless Enum.empty?(candidates), do: push_merge_candidates(candidates, system_user_id)
  end

  def get_merge_candidates(score, batch_size) do
    MergeCandidate
    |> where([m], m.status == ^MergeCandidate.status(:new) and m.score >= ^score)
    |> limit(^batch_size)
    |> Repo.all()
  end

  defp push_merge_candidates(candidates, system_user_id) do
    Enum.map(candidates, fn candidate ->
      event = %{id: candidate.id, master_person_id: candidate.master_person_id, merge_person_id: candidate.person_id}

      with :ok <- @kafka_producer.publish_person_deactivation_event(event, system_user_id, @reason) do
        candidate
        |> MergeCandidate.changeset(%{status: MergeCandidate.status(:in_process)})
        |> Repo.update!()
      end
    end)
  end
end
