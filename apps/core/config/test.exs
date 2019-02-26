use Mix.Config

# Configuration for test environment
System.put_env("MAX_PERSONS_RESULT", "2")

config :ex_unit, capture_log: true

# Print only warnings and errors during test
config :logger, level: :warn

# Configure your database
config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "mpi_test",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 120_000_000,
  loggers: [{EhealthLogger.Ecto, :log, [:info]}]

config :core, Core.DeduplicationRepo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "deduplication_test",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  pool: Ecto.Adapters.SQL.Sandbox,
  ownership_timeout: 120_000_000,
  loggers: [{EhealthLogger.Ecto, :log, [:info]}]
