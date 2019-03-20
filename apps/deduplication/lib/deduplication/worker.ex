defmodule Deduplication.Worker do
  @moduledoc """
  Synchronously get persons, candidates from replica, mark last updated_at and locks ids
  """
  use Confex, otp_app: :deduplication
  use GenServer
  alias Deduplication.V2.Model

  require Logger

  def produce_persons(demand), do: GenServer.call(__MODULE__, {:produce, demand})

  def start_link(_) do
    mode = config()[:mode]

    __MODULE__
    |> GenServer.start_link(%{mode: mode, offset: 0}, name: __MODULE__)
    |> start()
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
  def handle_call({:produce, demand}, _, %{mode: :new} = state), do: {:reply, get_persons(demand), state}

  def handle_call({:produce, demand}, _, %{mode: mode, offset: offset}) do
    locked_persons = get_locked_persons(demand, offset)
    locked_persons_number = Enum.count(locked_persons)

    case mode do
      :locked ->
        {:reply, locked_persons, %{mode: mode, offset: offset + locked_persons_number}}

      :mixed ->
        if locked_persons_number < demand do
          persons = get_persons(demand - locked_persons_number)
          {:reply, persons ++ locked_persons, %{mode: :new}}
        else
          {:reply, locked_persons, %{mode: mode, offset: offset + demand}}
        end
    end
  end

  def handle_call(what, _from, state) do
    Logger.error("Unhandled message #{what} were received, state: #{state}")
    {:reply, [], state}
  end

  defp get_persons(demand), do: Model.get_unverified_persons(demand)
  defp get_locked_persons(demand, offset), do: Model.get_locked_unverified_persons(demand, offset)

  def start({:ok, pid} = worker) do
    Model.store_deduplication_details()
    if config()[:vacuum_refresh], do: send(pid, :vacuum)
    worker
  end

  defp refresh_stat, do: Model.cleanup_locked_persons()
end
