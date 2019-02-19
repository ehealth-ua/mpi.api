use Mix.Config

config :kaffe,
  producer: [endpoints: {:system, :string, "KAFKA_BROKERS"}]

# Do not print debug messages in production
config :logger, level: :info
