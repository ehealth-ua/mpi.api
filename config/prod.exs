use Mix.Config

# Configuration for production environment
# It read environment variables to follow 12 factor apps convention.


# Configure your database
config :mpi_api, MpiApi.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "${DB_NAME}",
  username: "${DB_USER}",
  password: "${DB_PASSWORD}",
  hostname: "${DB_HOST}",
  port: "${DB_PORT}"
