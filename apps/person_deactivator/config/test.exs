use Mix.Config

config :person_deactivator,
  producer: PersonDeactivatorKafkaMock

config :logger, level: :warn
