use Mix.Config

config :person_deactivator,
  producer: PersonDeactivator.Kafka.Producer,
  rpc_worker: PersonDeactivator.Rpc.Worker

config :person_deactivator, PersonDeactivator.Application, env: Mix.env()

config :kaffe,
  producer: [
    endpoints: [localhost: 9092],
    topics: ["deactivate_declaration_events"]
  ]

config :person_deactivator,
  kaffe_consumer: [
    endpoints: [localhost: 9092],
    topics: ["deactivate_person_events"],
    consumer_group: "deactivate_person_events_group",
    message_handler: PersonDeactivator.Kafka.Consumer
  ]

import_config "#{Mix.env()}.exs"
