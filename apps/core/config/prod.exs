use Mix.Config

# 1 week in ms
queue_target = 604_800_000
queue_interval = queue_target + 1000

config :core, Core.Repo,
  username: {:system, :string, "DB_USER"},
  password: {:system, :string, "DB_PASSWORD"},
  database: {:system, :string, "DB_NAME"},
  hostname: {:system, :string, "DB_HOST"},
  port: {:system, :integer, "DB_PORT"},
  pool_size: {:system, :integer, "POOL_SIZE", 10},
  timeout: :infinity,
  queue_target: queue_target,
  queue_interval: queue_interval

config :core, Core.ReadRepo,
  username: {:system, :string, "READ_DB_USER"},
  password: {:system, :string, "READ_DB_PASSWORD"},
  database: {:system, :string, "READ_DB_NAME"},
  hostname: {:system, :string, "READ_DB_HOST"},
  port: {:system, :integer, "READ_DB_PORT"},
  pool_size: {:system, :integer, "READ_DB_POOL_SIZE", 10},
  timeout: :infinity,
  queue_target: queue_target,
  queue_interval: queue_interval

config :core, Core.DeduplicationRepo,
  username: {:system, :string, "DB_DEDUPLICATION_USER"},
  password: {:system, :string, "DB_DEDUPLICATION_PASSWORD"},
  database: {:system, :string, "DB_DEDUPLICATION_NAME"},
  hostname: {:system, :string, "DB_DEDUPLICATION_HOST"},
  port: {:system, :integer, "DB_DEDUPLICATION_PORT"},
  pool_size: {:system, :integer, "DEDUPLICATION_POOL_SIZE", 10},
  timeout: :infinity,
  queue_target: queue_target,
  queue_interval: queue_interval
