defmodule PersonDeactivator.Kafka.Producer do
  @moduledoc false

  require Logger
  @person_events_topic "deactivate_declaration_events"
  @behaviour PersonDeactivatorProducer.Behaviours.KafkaProducerBehaviour

  def publish_person_merged_event(merged_person_id, system_user_id) do
    event = %{"person_id" => merged_person_id, "actor_id" => system_user_id}

    with :ok <- KafkaEx.produce(@person_events_topic, 0, :erlang.term_to_binary(event)) do
      Logger.info("Person #{merged_person_id} declarations will be deactivated")
      :ok
    end
  end
end
