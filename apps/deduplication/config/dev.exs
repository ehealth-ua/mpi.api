use Mix.Config

# Do not include metadata nor timestamps in development logs
config :logger, :console, format: "$message\n"

config :deduplication, Deduplication.Match,
  subscribers: [
    {:system, "DEDUPLICATION_SUBSCRIBER_IL", "http://localhost:4000/internal/deduplication/found_duplicates"}
  ]
