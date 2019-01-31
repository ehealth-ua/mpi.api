# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# Configures Elixir's Logger
config :logger, :console,
  format: "$message\n",
  metadata: [:request_id]

config :person_updates_producer,
  kafka: [
    producer: PersonUpdatesProducer.Kafka.Producer
  ]

config :person_updates_producer, PersonUpdatesProducer.Application, env: Mix.env()

config :person_updates_producer, PersonUpdatesProducer.Kafka.Producer,
  partitions: %{
    "person_events" => {:system, :integer, "PERSON_EVENTS_PARTITIONS"}
  }

config :person_updates_producer, PersonUpdatesProducer.Jobs.PersonUpdatesPublisher,
  batch_size: {:system, :integer, "BATCH_SIZE", 100}

config :person_updates_producer, PersonUpdatesProducer.Worker,
  person_updates_producer_schedule: {:system, :string, "PERSON_UPDATES_SCHEDULE", "*/15 * * * *"}

config :kafka_ex,
  brokers: "localhost:9092",
  disable_default_worker: false,
  sync_timeout: 3000,
  max_restarts: 10,
  max_seconds: 60,
  commit_interval: 5_000,
  auto_offset_reset: :earliest,
  commit_threshold: 100,
  kafka_version: "1.1.0"

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
