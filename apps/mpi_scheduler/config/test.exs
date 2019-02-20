use Mix.Config

# Print only warnings and errors during test
config :logger, level: :warn

config :mpi_scheduler,
  person_deactivator_producer: MPISchedulerKafkaMock
