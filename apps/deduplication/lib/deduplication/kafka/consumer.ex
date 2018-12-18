defmodule Deduplication.Kafka.GenConsumer do
  @moduledoc false
  use KafkaEx.GenConsumer
  alias Core.Person
  alias Core.Persons.PersonsAPI
  require Logger
  @person_status_inactive Person.status(:inactive)

  # note - messages are delivered in batches
  def handle_message_set(message_set, state) do
    for %Message{value: message, offset: offset} <- message_set do
      with %{"person_id" => person_id, "actor_id" => actor_id} <- :erlang.binary_to_term(message) do
        deactivate_person(person_id, actor_id)
      else
        _ ->
          Logger.error("Unhandled message: #{inspect(message)}, offset: #{offset}")
      end
    end

    {:async_commit, state}
  end

  def deactivate_person(person_id, actor_id) do
    with {:ok, %Person{status: @person_status_inactive}} <-
           PersonsAPI.update(person_id, %{"status" => @person_status_inactive}, actor_id) do
      :ok
    else
      error ->
        Logger.error("Person is not activated: #{inspect(error)}")
        error
    end
  end
end
