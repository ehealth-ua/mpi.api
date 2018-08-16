use Mix.Config

# Configuration for test environment
System.put_env("MAX_PERSONS_RESULT", "2")

config :mpi,
  kafka: [
    producer: KafkaMock
  ]

# We don't run a server during test. If one is required,
# you can enable the server option below.
config :mpi, MPI.Web.Endpoint,
  http: [port: 4001],
  server: false

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :mpi, MPI.Repo,
  adapter: Ecto.Adapters.Postgres,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "mpi_test"

config :mpi, MPI.Deduplication.Match,
  subscribers: {:system, "DEDUPLICATION_SUBSCRIBERS_LIST", ["http://no-http-call-expected"]}

config :mpi, :deduplication_client, DeduplicationClientMock
