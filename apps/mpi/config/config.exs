use Mix.Config

# Configures the endpoint
config :mpi, MPI.Web.Endpoint,
  url: [host: "localhost"],
  secret_key_base: "bvzeKHzH8k+qavTDh5NTxFcnPVHIL+Ybi1Bucq2TrJ3I3zqbXEqFr37QbrL0c202",
  render_errors: [view: EView.Views.PhoenixError, accepts: ~w(json)]

config :mpi, person_deactivator_producer: MPI.Kafka.PersonDeactivatorProducer

config :kaffe,
  producer: [
    endpoints: [localhost: 9092],
    topics: ["deactivate_person_events"]
  ]

import_config "#{Mix.env()}.exs"
