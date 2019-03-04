defmodule CandidatesMerger.Kafka.Behaviour do
  @moduledoc false

  @callback publish_person_deactivation_event(candidate :: map, updated_by :: binary, reason :: binary) ::
              :ok
              | {:ok, integer}
              | {:error, :closed}
              | {:error, :inet.posix()}
              | {:error, any}
              | iodata
              | :leader_not_available
end
