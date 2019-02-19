defmodule PersonUpdatesProducer.Kafka.Producer do
  @moduledoc false

  @person_events_topic "person_events"
  @behaviour PersonUpdatesProducer.Behaviours.KafkaProducerBehaviour

  use Confex, otp_app: :person_updates_producer
  alias Kaffe.Producer
  require Logger

  def publish_person_event(id, status, updated_by) do
    event = %{"id" => id, "status" => String.downcase(status), "updated_by" => updated_by}

    with :ok <- Producer.produce_sync(@person_events_topic, get_partition(id), nil, :erlang.term_to_binary(event)) do
      Logger.info("Published event #{inspect(event)} to kafka", application: :kaffe)
      :ok
    end
  end

  defp get_partition(id) do
    partitions_number = config()[:partitions][@person_events_topic] - 1
    {i, _} = Integer.parse(String.first(id), 16)
    trunc(i * partitions_number / 12)
  end
end
