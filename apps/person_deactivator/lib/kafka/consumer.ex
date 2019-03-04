defmodule PersonDeactivator.Kafka.Consumer do
  @moduledoc false

  require Logger

  def handle_message(%{offset: offset, value: value}) do
    value = :erlang.binary_to_term(value)
    Logger.debug(fn -> "message: " <> inspect(value) end)
    Logger.info(fn -> "offset: #{offset}" end)
    :ok = consume(value)
  end

  def consume(%{"candidate" => candidate, "actor_id" => system_user_id, "reason" => reason}) do
    PersonDeactivator.deactivate_person(candidate, system_user_id, reason)
    :ok
  end

  def consume(value) do
    Logger.warn(fn -> "Kafka message cannot be processed: #{inspect(value)}" end)
    :ok
  end
end
