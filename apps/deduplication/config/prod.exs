use Mix.Config

config :logger, level: :info
config :kafka_ex, brokers: "${KAFKA_BROKERS_HOST}"
