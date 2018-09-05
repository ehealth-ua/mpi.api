use Mix.Config

config :person_updates_producer,
  kafka: [
    producer: KafkaMock
  ],
  worker: WorkerMock

# Print only warnings and errors during test
config :logger, level: :warn
