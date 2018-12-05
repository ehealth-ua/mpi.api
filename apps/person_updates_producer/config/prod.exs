use Mix.Config

config :kafka_ex, brokers: {:system, :string, "KAFKA_BROKERS"}

# Do not print debug messages in production
config :logger, level: :info
