use Mix.Config

config :person_deactivator,
  worker: PersonDeactivatorWorkerMock,
  producer: PersonDeactivatorKafkaMock

config :person_deactivator, PersonDeactivator,
  score: {:system, "DEACTIVATION_SCORE", "0.5"},
  kafka_score: {:system, "KAFKA_DEACTIVATION_SCORE", "0.8"},
  batch_size: {:system, :integer, "DEACTIVATION_BATCH_SIZE", 1},
  deactivation_limit: {:system, :integer, "DEACTIVATION_LIMIT", 10}
