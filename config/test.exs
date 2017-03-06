use Mix.Config

# Configuration for test environment


# Configure your database
config :mpi_api, MpiApi.Repo,
  pool: Ecto.Adapters.SQL.Sandbox,
  database: "mpi_api_test"
