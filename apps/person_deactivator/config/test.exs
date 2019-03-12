use Mix.Config

config :person_deactivator,
  producer: PersonDeactivatorKafkaMock,
  rpc_worker: RPCWorkerMock

config :logger, level: :warn
