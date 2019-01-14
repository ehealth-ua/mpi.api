defmodule Deduplication.Producer do
  @moduledoc """
  produce unverified persons
  """
  use GenStage
  alias Deduplication.V2.Model
  require Logger
  @behaviour Deduplication.Behaviours.ProducerBehaviour

  def start_link(%{id: id}) do
    GenStage.start_link(__MODULE__, %{}, name: id, id: id)
  end

  @impl true
  def init(%{} = _state) do
    {:producer, %{call: :zero, offset: 0}, []}
  end

  @impl true
  def handle_demand(demand, %{call: :normal} = state) when demand > 0 do
    {:noreply, unverified_persons(demand), state}
  end

  def handle_demand(demand, %{call: :zero, offset: offset}) when demand > 0 do
    persons = Model.get_failed_unverified_persons(demand, offset)

    if persons == [] do
      {:noreply, unverified_persons(demand), %{call: :normal}}
    else
      {:noreply, persons, %{call: :zero, offset: offset + demand}}
    end
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  @impl true
  def stop_application do
    Logger.info("Stop application")
    System.halt(0)
  end

  defp unverified_persons(demand) do
    persons = Model.get_unverified_persons(demand)
    Model.lock_persons_on_verify(Enum.map(persons, & &1.id))
    persons
  end
end
