defmodule Deduplication.Worker do
  @moduledoc """
  Synchronously get persons, candidates from replica, mark last updated_at and locks ids
  """
  use Confex, otp_app: :deduplication
  use GenServer
  alias Deduplication.V2.Model

  def produce_persons(demand), do: GenServer.call(__MODULE__, {:produce, demand})

  def start_link(_) do
    vacuum? = config()[:vacuum_refresh]
    mode = config()[:mode]
    Model.store_deduplication_details()

    {:ok, pid} = GenServer.start_link(__MODULE__, %{mode: mode, offset: 0}, name: __MODULE__)
    if vacuum?, do: send(pid, :vacuum)
    {:ok, pid}
  end

  @impl true
  def init(state), do: {:ok, state}

  @impl true
  def handle_info(:vacuum, state) do
    refresh_stat()
    Process.send_after(self(), :vacuum, config()[:vacuum_refresh_timeout])
    {:noreply, state}
  end

  @impl true
  def handle_call({:produce, demand}, _from, %{mode: :new} = state), do: {:reply, get_persons(demand), state}
  def handle_call({:produce, demand}, _from, %{mode: mode, offset: offset}), do: produce_and_state(demand, offset, mode)
  def handle_call(_what, _, state), do: {:reply, :not_implemented, state}

  defp produce_and_state(demand, offset, mode) do
    demand
    |> get_locked_persons(offset)
    |> produce_and_state(demand, offset, mode)
  end

  # The order of patterns is necessary, first check does locked_persons is not empty
  defp produce_and_state([], _demand, 0, :locked), do: {:reply, [], %{}}
  defp produce_and_state([], demand, 0, :mixed), do: {:reply, get_persons(demand), %{mode: :new}}
  defp produce_and_state([], demand, _offset, mode), do: produce_and_state(demand, 0, mode)
  defp produce_and_state(persons, demand, offset, mode), do: {:reply, persons, %{mode: mode, offset: offset + demand}}

  defp get_persons(demand), do: Model.get_unverified_persons(demand)
  defp get_locked_persons(demand, offset), do: Model.get_locked_unverified_persons(demand, offset)

  defp refresh_stat, do: Model.cleanup_locked_persons()
end
