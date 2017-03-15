use Mix.Config

config :mpi, MPI.Web.Endpoint,
  on_init: {MPI.Web.Endpoint, :load_from_system_env, []},
  url: [host: "example.com", port: 80]

# Do not print debug messages in production
config :logger, level: :info

config :mpi, MPI.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "${DB_NAME}",
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  hostname: "${DB_HOST}",
  port: "${DB_PORT}"

config :mpi, MPI.Web.Endpoint,
  http: [port: {:system, "APP_PORT"}],
  url:  [
    host: {:system, "APP_HOST"},
    port: {:system, "APP_PORT"},
  ],
  secret_key_base: {:system, "APP_SECRET_KEY"},
  debug_errors: false,
  code_reloader: false

# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
config :phoenix, :serve_endpoints, true
