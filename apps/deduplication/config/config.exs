# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$message\n",
  metadata: [:request_id]

# ENV DEDUPLICATION_MODE defines how producer will get persons
# :mixed - first get locked persons, then rest
# :new - get only unlocked unverified persons
# :locked - get only locked persons
config :deduplication, Deduplication.Worker,
  mode: {:system, :atom, "DEDUPLICATION_MODE", :mixed},
  vacuum_refresh: true,
  vacuum_refresh_timeout: {:system, :integer, "DEDUPLICATION_VACUUM_REFRESH_TIMEOUT", 5000}

config :deduplication,
  producer: Deduplication.Producer,
  client: HTTPoison,
  py_weight: Deduplication.V2.PyWeight,
  python_workers_pool_size: {:system, :integer, "PYTHON_WORKERS_POOL_SIZE", 10}

config :deduplication, Deduplication.Application,
  env: Mix.env(),
  parallel_consumers: {:system, :integer, "DEDUPLICATION_PARALLEL_TASKS", 20}

config :deduplication, Deduplication.Consumer,
  deduplication_persons_limit: {:system, :integer, "DEDUPLICATION_PERSON_LIMIT", 40}

config :deduplication, Deduplication.V2.Model,
  candidates_batch_size: {:system, :integer, "DEDUPLICATION_CANDIDATES_BATCH_SIZE", 50_000}

config :deduplication, Deduplication.V2.Match,
  score: {:system, :float, "DEDUPLICATION_SCORE", 0.7},
  manual_score_min: {:system, :float, "DEDUPLICATION_MANUAL_SCORE_MIN", 0.7},
  manual_score_max: {:system, :float, "DEDUPLICATION_MANUAL_SCORE_MAX", 0.9},
  weight_count_timeout: {:system, :integer, "WEIGHT_COUNT_TIMEOUT", 20000}

config :deduplication, Deduplication.V1.Match,
  schedule: {:system, "DEDUPLICATION_SCHEDULE", "* * * * *"},
  depth: {:system, :integer, "DEDUPLICATION_DEPTH", 20},
  score: {:system, "DEDUPLICATION_SCORE", "0.8"},
  fields: %{
    tax_id: %{match: 0.5, no_match: -0.1},
    first_name: %{match: 0.1, no_match: -0.1},
    last_name: %{match: 0.2, no_match: -0.1},
    second_name: %{match: 0.1, no_match: -0.1},
    birth_date: %{match: 0.5, no_match: -0.1},
    documents: %{match: 0.3, no_match: -0.1},
    unzr: %{match: 0.4, no_match: -0.1},
    phones: %{match: 0.3, no_match: -0.1}
  }

import_config "#{Mix.env()}.exs"
