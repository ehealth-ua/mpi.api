defmodule Deduplication.Producer do
  @moduledoc """
  produce unverified persons
  """
  use Confex, otp_app: :deduplication
  use GenStage
  alias Deduplication.V2.Model
  require Logger

  def start_link(%{id: id}) do
    GenStage.start_link(__MODULE__, %{}, name: id, id: id)
  end

  @impl true
  def init(%{} = _state) do
    mode = config()[:mode]
    {:producer, %{mode: mode, offset: 0}, []}
  end

  @impl true
  def handle_demand(demand, %{mode: :new} = state) when demand > 0 do
    {:noreply, unverified_persons(demand), state}
  end

  def handle_demand(demand, %{mode: mode, offset: offset}) when demand > 0 do
    locked_persons = Model.get_locked_unverified_persons(demand, offset)

    # The order of cond is nessesary, first check does locked_persons is not empty
    cond do
      not Enum.empty?(locked_persons) ->
        {:noreply, locked_persons, %{mode: mode, offset: offset + demand}}

      mode == :mixed ->
        {:noreply, unverified_persons(demand), %{mode: :new}}

      mode == :locked ->
        {:noreply, [], %{}}
    end
  end

  def handle_demand(_demand, state) do
    {:noreply, [], state}
  end

  defp unverified_persons(demand) do
    persons = Model.get_unverified_persons(demand)
    Model.lock_persons_on_verify(Enum.map(persons, & &1.id))
    persons
  end
end
