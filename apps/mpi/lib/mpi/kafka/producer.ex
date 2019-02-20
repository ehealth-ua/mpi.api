defmodule MPI.Kafka.PersonDeactivatorProducer do
  @moduledoc false

  alias Kaffe.Producer

  require Logger

  @person_events_topic "deactivate_person_events"
  @behaviour MPIScheduler.Behaviours.KafkaProducerBehaviour

  def publish_person_deactivation_event(%{id: id, person_id: person_id}, system_user_id) do
    event = %{"candidates" => [%{id: id, person_id: person_id}], "actor_id" => system_user_id}

    with :ok <- Producer.produce_sync(@person_events_topic, 0, nil, :erlang.term_to_binary(event)) do
      Logger.info("Published event #{inspect(event)} to kafka", application: :kaffe)
      :ok
    end
  end
end
