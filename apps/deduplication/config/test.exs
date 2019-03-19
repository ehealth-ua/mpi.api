use Mix.Config

config :deduplication, Deduplication.V2.Match, py_weight: PyWeightMock

# Print only warnings and errors during test
config :logger, level: :info
config :ex_unit, capture_log: true

config :deduplication, Deduplication.V2.Model,
  candidates_batch_size: {:system, :integer, "DEDUPLICATION_CANDIDATES_BATCH_SIZE", 2}

config :deduplication, Deduplication.Consumer,
  deduplication_persons_limit: {:system, :integer, "DEDUPLICATION_PERSON_LIMIT", 100}

config :deduplication, Deduplication.V2.GenStageTest,
  parallel_consumers: {:system, :integer, "DEDUPLICATION_PARALLEL_TASKS", 4}

config :deduplication, Deduplication.Worker,
  vacuum_refresh: false,
  mode: :mixed
