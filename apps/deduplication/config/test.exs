use Mix.Config

config :deduplication,
  worker: WorkerMock,
  client: ClientMock

# Print only warnings and errors during test
config :logger, level: :warn

config :deduplication, Deduplication.Match,
  subscribers: {:system, "DEDUPLICATION_SUBSCRIBERS_LIST", ["http://no-http-call-expected"]}
