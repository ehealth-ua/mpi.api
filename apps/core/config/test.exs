use Mix.Config

# Configuration for test environment
System.put_env("MAX_PERSONS_RESULT", "2")

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "mpi_test",
  ownership_timeout: 120_000_000

config :core, Core.Deduplication.Match,
  subscribers: {:system, "DEDUPLICATION_SUBSCRIBERS_LIST", ["http://no-http-call-expected"]}

config :core, :deduplication_client, DeduplicationClientMock
