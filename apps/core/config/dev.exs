use Mix.Config

config :core, Core.Repo,
  username: "postgres",
  password: "postgres",
  database: "mpi_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10

config :core, Core.ReadRepo,
  username: "postgres",
  password: "postgres",
  database: "mpi_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10

config :core, Core.DeduplicationRepo,
  username: "postgres",
  password: "postgres",
  database: "deduplication_dev",
  hostname: "localhost",
  port: 5432,
  pool_size: 10
