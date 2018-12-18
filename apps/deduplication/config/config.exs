# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
use Mix.Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$message\n",
  metadata: [:request_id]

config :deduplication,
  worker: Deduplication.Worker,
  producer: Deduplication.Kafka.Producer,
  client: HTTPoison,
  py_weight: Deduplication.V2.PyWeight

config :deduplication, Deduplication.Application, env: Mix.env()

config :deduplication, Deduplication.Worker,
  deduplication_persons_limit: {:system, :integer, "DEDUPLICATION_PERSON_LIMIT", 50},
  parallel_tasks: {:system, :integer, "DEDUPLICATION_PARRALEL_TASKS", 10}

config :deduplication, Deduplication.V2.Match,
  score: {:system, "DEDUPLICATION_SCORE", "0.7"},
  kafka_score: {:system, "DEDUPLICATION_SCORE", "0.9"}

config :deduplication, Deduplication.V1.Match,
  subscribers: [
    {:system, "DEDUPLICATION_SUBSCRIBER_IL", "http://api-svc.il/internal/deduplication/found_duplicates"}
  ],
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

config :kafka_ex,
  brokers: "localhost:9092",
  consumer_group: "deactivate_person_events",
  disable_default_worker: false,
  sync_timeout: 3000,
  max_restarts: 10,
  max_seconds: 60,
  commit_interval: 5_000,
  auto_offset_reset: :earliest,
  commit_threshold: 100,
  kafka_version: "1.1.0"

import_config "#{Mix.env()}.exs"
