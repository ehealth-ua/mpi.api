use Mix.Config

config :logger, level: :warn
config :ex_unit, capture_log: true

config :mpi_scheduler, MPIScheduler.Jobs.ManualMergeCandidatesCreator,
  select_batch_size: 40,
  select_max_candidates: 120,
  insert_batch_size: 5,
  manual_score_min: 0.7,
  manual_score_max: 0.9
