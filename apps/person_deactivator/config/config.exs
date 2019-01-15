use Mix.Config

config :person_deactivator,
  producer: PersonDeactivator.Kafka.Producer,
  worker: PersonDeactivator.Worker

config :person_deactivator, PersonDeactivator,
  kafka_score: {:system, "KAFKA_DEACTIVATION_SCORE", "0.9"},
  batch_size: {:system, :integer, "DEACTIVATION_BATCH_SIZE", 500},
  deactivation_limit: {:system, :integer, "DEACTIVATION_LIMIT", 1000}

config :person_deactivator, PersonDeactivator.Application, env: Mix.env()

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
