# This file is responsible for configuring your application
# and its dependencies with the aid of the Mix.Config module.
#
# This configuration file is loaded before any dependency and
# is restricted to this project.
use Mix.Config

config :core, repos: [read_repo: Core.ReadRepo]

# General application configuration
config :core,
  namespace: Core,
  ecto_repos: [Core.Repo, Core.ReadRepo, Core.DeduplicationRepo],
  max_persons_result: {:system, :integer, "MAX_PERSONS_RESULT", 15},
  system_user: {:system, "EHEALTH_SYSTEM_USER", "4261eacf-8008-4e62-899f-de1e2f7065f0"},
  max_page_size: {:system, :integer, "MAX_PAGE_SIZE", 300},
  page_size: {:system, :integer, "PAGE_SIZE", 50}

config :core, Core.ManualMerge, max_postponed_requests: {:system, :integer, "MAX_POSTPONED_MANUAL_MERGE_REQUESTS", 5}

config :logger_json, :backend,
  formatter: EhealthLogger.Formatter,
  metadata: :all

config :logger,
  backends: [LoggerJSON],
  level: :info

# It is also possible to import configuration files, relative to this
# directory. For example, you can emulate configuration per environment
# by uncommenting the line below and defining dev.exs, test.exs and such.
# Configuration from the imported file will override the ones defined
# here (which is why it is important to import them last).

config :ecto_trail, table_name: "audit_log_mpi"

config :core, Core.DeduplicationRepo,
  after_connect: {Core.DeduplicationRepo, :set_runtime_params, []},
  runtime_params: [
    {"manual_merge_requests.max_postponed", {:system, "MAX_POSTPONED_MANUAL_MERGE_REQUESTS", "5"}}
  ]

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{Mix.env()}.exs"
