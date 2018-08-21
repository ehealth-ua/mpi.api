defmodule MPI.Behaviours.KafkaProducerBehaviour do
  @moduledoc false

  @callback publish_person_event(id :: binary, status :: binary, updated_by :: binary) ::
              :ok
              | {:ok, integer}
              | {:error, :closed}
              | {:error, :inet.posix()}
              | {:error, any}
              | iodata
              | :leader_not_available
end
