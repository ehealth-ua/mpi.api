defmodule PersonDeactivator.Kafka.Consumer do
  @moduledoc false

  require Logger

  def handle_message(%{offset: offset, value: value}) do
    value = :erlang.binary_to_term(value)
    Logger.metadata(request_id: value.request_id, job_id: value._id)
    Logger.debug(fn -> "message: " <> inspect(value) end)
    Logger.info(fn -> "offset: #{offset}" end)
    :ok = consume(value)
  end

  def consume(%{"candidates" => candidates, "actor_id" => system_user_id}) do
    PersonDeactivator.deactivate_persons(candidates, system_user_id)
    :ok
  end

  def consume(value) do
    Logger.warn(fn -> "Kafka message cannot be processed: #{inspect(value)}" end)
    :ok
  end
end
