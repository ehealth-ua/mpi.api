use Mix.Config

config :kaffe,
  producer: [
    endpoints: {:system, :string, "KAFKA_BROKERS"},
    topics: ["deactivate_person_events"]
  ]

config :logger, level: :info
