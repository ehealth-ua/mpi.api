# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

# General application configuration
config :core,
  namespace: Core,
  ecto_repos: [Core.Repo],
  max_persons_result: {:system, :integer, "MAX_PERSONS_RESULT", 15},
  system_user: {:system, "EHEALTH_SYSTEM_USER", "4261eacf-8008-4e62-899f-de1e2f7065f0"}

# Configures Elixir's Logger
config :logger, :console,
  format: "$message\n",
  handle_otp_reports: true,
  level: :info

config :core, Core.Deduplication.Match,
  subscribers: [
    {:system, "DEDUPLICATION_SUBSCRIBER_IL", "http://api-svc.il/internal/deduplication/found_duplicates"}
  ],
  schedule: {:system, "DEDUPLICATION_SCHEDULE", "* * * * *"},
  depth: {:system, :integer, "DEDUPLICATION_DEPTH", 20},
  score: {:system, "DEDUPLICATION_SCORE", "0.8"},
  fields: %{
    tax_id: %{match: 0.5, no_match: -0.1},
    first_name: %{match: 0.1, no_match: -0.1},
    last_name: %{match: 0.2, no_match: -0.1},
    second_name: %{match: 0.1, no_match: -0.1},
    birth_date: %{match: 0.5, no_match: -0.1},
    documents: %{match: 0.3, no_match: -0.1},
    unzr: %{match: 0.4, no_match: -0.1},
    phones: %{match: 0.3, no_match: -0.1}
  }

config :core, Core.Repo,
  adapter: Ecto.Adapters.Postgres,
  username: "postgres",
  password: "postgres",
  database: "mpi_dev",
  hostname: "localhost",
  pool_size: 10,
  loggers: [{Ecto.LoggerJSON, :log, [:info]}]

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).

config :ecto_trail, table_name: "audit_log_mpi"

config :core, :deduplication_client, HTTPoison

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
