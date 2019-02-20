use Mix.Config

# Do not print debug messages in production
config :logger, level: :info

config :kaffe,
  producer: [
    endpoints: {:system, :string, "KAFKA_BROKERS"},
    topics: ["deactivate_person_events"]
  ]
