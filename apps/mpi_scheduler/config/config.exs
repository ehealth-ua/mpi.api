use Mix.Config

config :mpi_scheduler, MPIScheduler.Worker,
  auto_merge_persons_deactivator_schedule: {:system, :string, "PERSON_AUTO_DEACTIVATION_SCHEDULE", "0 0 * * *"}

config :mpi_scheduler, MPIScheduler.Jobs.AutoMergePersonsDeactivator,
  score: {:system, :float, "PERSON_AUTO_DEACTIVATION_SCORE", 0.9},
  batch_size: {:system, :integer, "PERSON_AUTO_DEACTIVATION_BATCH_SIZE", 500}

import_config "#{Mix.env()}.exs"