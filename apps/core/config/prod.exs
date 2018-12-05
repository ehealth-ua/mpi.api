use Mix.Config

config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: {:system, :string, "DB_USER"},
  password: {:system, :string, "DB_PASSWORD"},
  database: {:system, :string, "DB_NAME"},
  hostname: {:system, :string, "DB_HOST"},
  port: {:system, :integer, "DB_PORT"},
  pool_size: 10,
  loggers: [{Ecto.LoggerJSON, :log, [:info]}]
