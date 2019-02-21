use Mix.Config

config :candidates_merger,
  producer: CandidatesMerger.Kafka.Producer

config :candidates_merger, CandidatesMerger, quorum: {:system, :integer, "MANUAL_MERGE_QUORUM", 3}

config :kaffe,
  producer: [
    endpoints: [localhost: 9092],
    topics: ["deactivate_person_events"]
  ]

import_config "#{Mix.env()}.exs"
