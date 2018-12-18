use Mix.Config

config :deduplication,
  worker: DeduplicationWorkerMock,
  producer: DeduplicationKafkaMock,
  client: ClientMock,
  py_weight: PyWeightMock

# Print only warnings and errors during test
config :logger, level: :info

config :deduplication, Deduplication.V2.Match,
  subscribers: {:system, "DEDUPLICATION_SUBSCRIBERS_LIST", ["http://no-http-call-expected"]}

config :deduplication, Deduplication.Worker,
  deduplication_persons_limit: {:system, :integer, "DEDUPLICATION_PERSON_LIMIT", 100},
  parallel_tasks: {:system, :integer, "DEDUPLICATION_PARRALEL_TASKS", 40}
