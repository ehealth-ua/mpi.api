defmodule DeduplicationProducer.Behaviours.KafkaProducerBehaviour do
  @moduledoc false

  @callback publish_person_merged_event(merged_person_id :: binary, updated_by :: binary) ::
              :ok
              | {:ok, integer}
              | {:error, :closed}
              | {:error, :inet.posix()}
              | {:error, any}
              | iodata
              | :leader_not_available
end
