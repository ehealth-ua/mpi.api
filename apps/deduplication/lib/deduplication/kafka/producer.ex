defmodule Deduplication.Kafka.Producer do
  @moduledoc false

  @person_events_topic "deactivate_declaration_events"
  @behaviour DeduplicationProducer.Behaviours.KafkaProducerBehaviour

  require Logger

  def publish_person_merged_event(merged_person_id, system_user_id) do
    event = %{"merged_person_id" => merged_person_id, "actor_id" => system_user_id}

    with :ok <- KafkaEx.produce(@person_events_topic, 0, :erlang.term_to_binary(event)) do
      Logger.info("Published event #{inspect(event)} to kafka", application: :kafka_ex)
      :ok
    end
  end
end
