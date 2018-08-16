defmodule MPI.Kafka.Producer do
  @moduledoc false

  @person_events_topic "person_events"
  @behaviour MPI.Behaviours.KafkaProducerBehaviour

  require Logger

  def publish_person_event(id, status) do
    event = %{"id" => id, "status" => String.downcase(status)}

    with :ok <- KafkaEx.produce(@person_events_topic, 0, :erlang.term_to_binary(event)) do
      Logger.info("Published event #{inspect(event)} to kafka", application: :kafka_ex)
      :ok
    end
  end
end
