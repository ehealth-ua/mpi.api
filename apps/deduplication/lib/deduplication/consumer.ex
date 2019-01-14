defmodule Deduplication.Consumer do
  @moduledoc """
  consume unverified persons
  """
  use Confex, otp_app: :deduplication
  use GenStage
  alias Deduplication.V2.Match

  def start_link(%{producer_id: producer_id, id: id}) do
    GenStage.start_link(__MODULE__, %{producer_id: producer_id}, name: id, id: id)
  end

  @impl true
  def init(%{producer_id: producer_id} = state) do
    demand = config()[:deduplication_persons_limit]
    {:consumer, state, subscribe_to: [{producer_id, max_demand: demand}]}
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_events(persons, _from, %{producer_id: _producer_id} = state) do
    Match.deduplicate_persons(persons)
    {:noreply, [], state}
  end

  @impl true
  def terminate(_reason, _state), do: :ok
end
