# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$message\n",
  metadata: [:request_id]

config :deduplication, Deduplication.Application, env: Mix.env()

config :deduplication, Deduplication.Scheduler,
  deduplication_schedule: {:system, :string, "DEDUPLICATION_SCHEDULE", "* * * * *"}

# ENV DEDUPLICATION_MODE defines how producer will get persons
# :mixed - first get locked persons, then rest
# :new - get only unlocked unverified persons
# :locked - get only locked persons
config :deduplication, Deduplication.Producer,
  mode: {:system, :atom, "DEDUPLICATION_MODE", :mixed},
  vacuum_refresh: true,
  vacuum_refresh_timeout: {:system, :integer, "DEDUPLICATION_VACUUM_REFRESH_TIMEOUT", 20_000}

config :deduplication, Deduplication.PythonPool,
  python_workers_pool_size: {:system, :integer, "PYTHON_WORKERS_POOL_SIZE", 10}

config :deduplication, Deduplication.DeduplicationPool,
  parallel_consumers: {:system, :integer, "DEDUPLICATION_PARALLEL_TASKS", 20},
  deduplication_persons_limit: {:system, :integer, "DEDUPLICATION_PERSON_LIMIT", 40},
  max_restarts: {:system, :integer, "MAX_RESTART_TRIES", 100_000_000}

config :deduplication, Deduplication.Model,
  candidates_batch_size: {:system, :integer, "DEDUPLICATION_CANDIDATES_BATCH_SIZE", 50_000}

config :deduplication, Deduplication.Match,
  py_weight: Deduplication.PyWeight,
  score: {:system, :float, "DEDUPLICATION_SCORE", 0.7},
  weight_count_timeout: {:system, :integer, "WEIGHT_COUNT_TIMEOUT", 20000}

import_config "#{Mix.env()}.exs"
