# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$message\n",
  metadata: [:request_id]

config :deduplication,
  producer: Deduplication.Producer,
  client: HTTPoison,
  py_weight: Deduplication.V2.PyWeight

config :deduplication, Deduplication.Application,
  env: Mix.env(),
  parallel_consumers: {:system, :integer, "DEDUPLICATION_PARALLEL_TASKS", 40}

config :deduplication, Deduplication.Consumer,
  deduplication_persons_limit: {:system, :integer, "DEDUPLICATION_PERSON_LIMIT", 400}

config :deduplication, Deduplication.V2.Model,
  candidates_batch_size: {:system, :integer, "DEDUPLICATION_CANDIDATES_BATCH_SIZE", 4000}

config :deduplication, Deduplication.V2.Match,
  score: {:system, "DEDUPLICATION_SCORE", "0.7"},
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
