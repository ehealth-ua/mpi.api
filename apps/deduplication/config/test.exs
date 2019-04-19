use Mix.Config

config :deduplication, Deduplication.Match, py_weight: PyWeightMock

# Print only warnings and errors during test
config :logger, level: :info
config :ex_unit, capture_log: true

config :deduplication, Deduplication.Model,
  candidates_batch_size: {:system, :integer, "DEDUPLICATION_CANDIDATES_BATCH_SIZE", 2}

config :deduplication, Deduplication.Producer, mode: :mixed, vacuum_refresh: false
