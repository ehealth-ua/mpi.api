use Mix.Config

config :person_deactivator,
  producer: PersonDeactivator.Kafka.Producer,
  worker: PersonDeactivator.Worker

config :person_deactivator, PersonDeactivator,
  kafka_score: {:system, "KAFKA_DEACTIVATION_SCORE", "0.9"},
  batch_size: {:system, :integer, "DEACTIVATION_BATCH_SIZE", 500},
  deactivation_limit: {:system, :integer, "DEACTIVATION_LIMIT", 1000}

config :person_deactivator, PersonDeactivator.Application, env: Mix.env()

config :kaffe,
  kafka_mod: :brod,
  producer: [
    endpoints: [localhost: 9092],
    topics: ["deactivate_person_events"]
  ]

import_config "#{Mix.env()}.exs"
