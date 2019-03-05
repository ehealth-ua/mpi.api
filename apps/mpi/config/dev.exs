use Mix.Config

config :mpi, MPI.Web.Endpoint,
  load_from_system_env: true,
  http: [port: {:system, "APP_PORT", 4000}],
  debug_errors: false,
  code_reloader: true,
  check_origin: false,
  watchers: []

config :phoenix, :stacktrace_depth, 20
