defmodule PersonDeactivator.Kafka.Producer do
  @moduledoc false

  require Logger
  alias Kaffe.Producer

  @person_events_topic "deactivate_declaration_events"
  @behaviour PersonDeactivatorProducer.Behaviours.KafkaProducerBehaviour

  def publish_declaration_deactivation_event(merged_person_id, system_user_id, reason) do
    event = %{"person_id" => merged_person_id, "actor_id" => system_user_id, "reason" => reason}

    with :ok <- Producer.produce_sync(@person_events_topic, "", :erlang.term_to_binary(event)) do
      Logger.info("Person #{merged_person_id} declarations will be deactivated")
      :ok
    end
  end
end
