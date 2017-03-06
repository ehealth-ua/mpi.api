use Mix.Config

# In this file, we keep production configuration that
# you likely want to automate and keep it away from
# your version control system.
#
# You should document the content of this
# file or create a script for recreating it, since it's
# kept out of version control and might be hard to recover
# or recreate for your teammates (or you later on).
config :mpi_api, MpiApi.Web.Endpoint,
  secret_key_base: "IbEPMZH42yu1iy5E8sZlEeVYaGtp3GHr7bRLlVql/kxbE8LxZsfSABLa8MUuHP8D"

# Configure your database
config :mpi_api, MpiApi.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "mpi_api_prod",
  pool_size: 15
