use Mix.Config

config :mpi, MPI.Web.Endpoint,
  load_from_system_env: true,
  http: [port: {:system, "APP_PORT"}],
  url:  [
    host: {:system, "APP_HOST"},
    port: {:system, "APP_PORT"},
  ],
  secret_key_base: {:system, "APP_SECRET_KEY"},
  debug_errors: false,
  code_reloader: false

config :mpi, MPI.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "${DB_NAME}",
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  hostname: "${DB_HOST}",
  port: "${DB_PORT}"

# If you are doing OTP releases, you need to instruct Phoenix
# to start the server for all endpoints:
config :phoenix, :serve_endpoints, true
