use Mix.Config

config :logger, level: :info

config :kaffe,
  producer: [endpoints: {:system, :string, "KAFKA_BROKERS"}]

config :person_deactivator,
  kaffe_consumer: [
    endpoints: {:system, :string, "KAFKA_BROKERS"},
    topics: ["deactivate_person_events"],
    consumer_group: "deactivate_person_events_group",
    message_handler: PersonDeactivator.Kafka.Consumer
  ]
