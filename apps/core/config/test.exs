use Mix.Config

# Configuration for test environment
System.put_env("MAX_PERSONS_RESULT", "2")

config :ex_unit, capture_log: true

config :core, repos: [read_repo: Core.Repo]

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  database: "mpi_test",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 120_000_000

config :core, Core.ReadRepo,
  username: "postgres",
  password: "postgres",
  database: "mpi_test",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 120_000_000

config :core, Core.DeduplicationRepo,
  username: "postgres",
  password: "postgres",
  database: "deduplication_test",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 120_000_000
