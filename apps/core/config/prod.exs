use Mix.Config

config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: {:system, :string, "DB_USER"},
  password: {:system, :string, "DB_PASSWORD"},
  database: {:system, :string, "DB_NAME"},
  hostname: {:system, :string, "DB_HOST"},
  port: {:system, :integer, "DB_PORT"},
  pool_size: {:system, :integer, "POOL_SIZE", 40},
  timeout: :infinity,
  loggers: [{EhealthLogger.Ecto, :log, [:info]}]

config :core, Core.ReadRepo,
  adapter: Ecto.Adapters.Postgres,
  username: {:system, :string, "DB_READ_USER"},
  password: {:system, :string, "DB_READ_PASSWORD"},
  database: {:system, :string, "DB_READ_NAME"},
  hostname: {:system, :string, "DB_READ_HOST"},
  port: {:system, :integer, "DB_READ_PORT"},
  pool_size: {:system, :integer, "READ_POOL_SIZE", 40},
  timeout: :infinity,
  loggers: [{EhealthLogger.Ecto, :log, [:info]}]

config :core, Core.DeduplicationRepo,
  adapter: Ecto.Adapters.Postgres,
  username: {:system, :string, "DB_DEDUPLICATION_USER"},
  password: {:system, :string, "DB_DEDUPLICATION_PASSWORD"},
  database: {:system, :string, "DB_DEDUPLICATION_NAME"},
  hostname: {:system, :string, "DB_DEDUPLICATION_HOST"},
  port: {:system, :integer, "DB_DEDUPLICATION_PORT"},
  pool_size: {:system, :integer, "DEDUPLICATION_POOL_SIZE", 40},
  timeout: :infinity,
  loggers: [{EhealthLogger.Ecto, :log, [:info]}]
