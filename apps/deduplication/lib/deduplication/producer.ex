defmodule Deduplication.Producer do
  @moduledoc """
  produce unverified persons
  """
  use Confex, otp_app: :deduplication
  use GenStage
  alias Deduplication.Worker
  require Logger

  def start_link(%{id: id}), do: GenStage.start_link(__MODULE__, %{}, name: id, id: id)

  @impl true
  def init(_state), do: {:producer, %{}, []}

  @impl true
  def handle_demand(demand, state) when demand > 0, do: {:noreply, Worker.produce_persons(demand), state}
  def handle_demand(_demand, state), do: {:noreply, [], state}
end
