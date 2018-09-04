use Mix.Config

config :person_updates_producer,
  kafka: [
    producer: KafkaMock
  ]

# Print only warnings and errors during test
config :logger, level: :warn
