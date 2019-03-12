use Mix.Config

config :mpi_scheduler, MPIScheduler.Worker,
  auto_merge_persons_deactivator_schedule: {:system, :string, "PERSON_AUTO_DEACTIVATION_SCHEDULE", "0 0 * * *"},
  manual_merge_candidates_creator_schedule: {:system, :string, "MANUAL_MERGE_CANDIDATES_CREATOR_SCHEDULE", "0 0 * * *"}

config :mpi_scheduler, MPIScheduler.Jobs.AutoMergePersonsDeactivator,
  score: {:system, :float, "PERSON_AUTO_DEACTIVATION_SCORE", 0.9},
  batch_size: {:system, :integer, "PERSON_AUTO_DEACTIVATION_BATCH_SIZE", 500}

config :mpi_scheduler, MPIScheduler.Jobs.ManualMergeCandidatesCreator,
  select_batch_size: {:system, :integer, "DEDUPLICATION_MERGE_CANDIDATES_SELECT_BATCH_SIZE", 500},
  select_max_candidates: {:system, :integer, "DEDUPLICATION_MERGE_CANDIDATES_SELECT_MAX_AMOUNT", 10_000},
  insert_batch_size: {:system, :integer, "DEDUPLICATION_MANUAL_MERGE_CANDIDATES_INSERT_BATCH_SIZE", 100},
  manual_score_min: {:system, :float, "DEDUPLICATION_MANUAL_SCORE_MIN", 0.7},
  manual_score_max: {:system, :float, "DEDUPLICATION_MANUAL_SCORE_MAX", 0.9}

import_config "#{Mix.env()}.exs"
