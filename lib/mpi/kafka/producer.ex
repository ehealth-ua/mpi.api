defmodule MPI.Kafka.Producer do
  @moduledoc false

  @person_events_topic "person_events"
  @behaviour MPI.Behaviours.KafkaProducerBehaviour

  def publish_person_event(id, status) do
    KafkaEx.produce(@person_events_topic, 0, :erlang.term_to_binary(%{"id" => id, "status" => status}))
  end
end
