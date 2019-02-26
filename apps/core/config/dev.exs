use Mix.Config

config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "mpi_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  loggers: [{EhealthLogger.Ecto, :log, [:info]}]

config :core, Core.ReadRepo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "mpi_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  loggers: [{EhealthLogger.Ecto, :log, [:info]}]

config :core, Core.DeduplicationRepo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "deduplication_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10,
  loggers: [{EhealthLogger.Ecto, :log, [:info]}]
