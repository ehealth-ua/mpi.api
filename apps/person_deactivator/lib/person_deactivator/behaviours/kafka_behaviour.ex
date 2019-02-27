defmodule PersonDeactivatorProducer.Behaviours.KafkaProducerBehaviour do
  @moduledoc false

  @callback publish_declaration_deactivation_event(
              merged_person_id :: binary,
              updated_by :: binary,
              reason :: binary
            ) ::
              :ok
              | {:ok, integer}
              | {:error, :closed}
              | {:error, :inet.posix()}
              | {:error, any}
              | iodata
              | :leader_not_available
end
