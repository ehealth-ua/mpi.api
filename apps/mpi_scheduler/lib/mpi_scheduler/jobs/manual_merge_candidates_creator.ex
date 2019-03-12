defmodule MPIScheduler.Jobs.ManualMergeCandidatesCreator do
  @moduledoc """
  Cron Job that takes batch of MergeCandidates from MPI DB with score for gray zone
  and do bulk insert of ManualMergeCandidates into Deduplication DB.
  Maximum amount of MergeCandidates that allowed to fetch from MPI DB defined in config
  """

  use Confex, otp_app: :mpi_scheduler

  alias Core.ManualMerge
  alias Core.MergeCandidates.API

  require Logger

  def run do
    config = config()
    select_batch_size = config[:select_batch_size]
    select_max_candidates = config[:select_max_candidates]
    insert_batch_size = config[:insert_batch_size]
    score_min = config[:manual_score_min]
    score_max = config[:manual_score_max]
    system_user_id = Confex.fetch_env!(:core, :system_user)

    select_batch_size
    |> API.get_manual_merge_candidates(select_max_candidates, score_min, score_max)
    |> ManualMerge.create_manual_merge_candidates(insert_batch_size, system_user_id)
  end
end
