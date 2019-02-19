use Mix.Config

config :logger, level: :info

config :kaffe,
  producer: [endpoints: {:system, :string, "KAFKA_BROKERS"}]
