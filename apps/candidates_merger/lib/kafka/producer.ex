defmodule CandidatesMerger.Kafka.Producer do
  @moduledoc false

  alias Kaffe.Producer

  require Logger

  @person_events_topic "deactivate_person_events"
  @behaviour CandidatesMerger.Kafka.Behaviour

  def publish_person_deactivation_event(candidate, system_user_id, reason) do
    with event = %{"candidate" => candidate, "actor_id" => system_user_id, "reason" => reason},
         :ok <- Producer.produce_sync(@person_events_topic, "", :erlang.term_to_binary(event)) do
      Logger.info("Published event #{inspect(event)} to kafka", application: :kaffe)
      :ok
    end
  end
end
