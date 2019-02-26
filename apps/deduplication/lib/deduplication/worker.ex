defmodule Deduplication.Worker do
  @moduledoc """
  Synchronously get persons, candidates from replica, mark last updated_at and locks ids
  """
  use Confex, otp_app: :deduplication
  use GenServer
  alias Core.Repo
  alias Deduplication.V2.Model
  alias Ecto.Adapters.SQL

  def produce_persons(demand), do: GenServer.call(__MODULE__, {:produce, demand})

  def start_link(refresh) do
    {:ok, pid} = GenServer.start_link(__MODULE__, %{}, name: __MODULE__)
    if refresh, do: send(__MODULE__, :refresh)
    {:ok, pid}
  end

  @impl true
  def init(_state) do
    {:ok, %{mode: config()[:mode], offset: 0}}
  end

  @impl true
  def handle_info(:refresh, state) do
    refresh_stat()
    Process.send_after(self(), :refresh, config()[:refresh_timeout])
    {:noreply, state}
  end

  @impl true
  def handle_call({:produce, demand}, _from, %{mode: :new} = state), do: {:reply, get_persons(demand), state}
  def handle_call({:produce, demand}, _from, %{mode: mode, offset: offset}), do: procude_and_state(demand, offset, mode)
  def handle_call(_what, _, state), do: {:reply, :not_implemented, state}

  defp procude_and_state(demand, offset, mode) do
    persons = get_locked_persons(demand, offset)
    procude_and_state(persons, demand, offset, mode)
  end

  # The order of patterns is nessesary, first check does locked_persons is not empty
  defp procude_and_state([], _demand, 0, :locked), do: {:reply, [], %{}}
  defp procude_and_state([], demand, 0, :mixed), do: {:reply, get_persons(demand), %{mode: :new}}
  defp procude_and_state([], demand, _offset, mode), do: procude_and_state(demand, 0, mode)
  defp procude_and_state(persons, demand, offset, mode), do: {:reply, persons, %{mode: mode, offset: offset + demand}}

  defp refresh_stat, do: SQL.query!(Repo, "VACUUM ANALYZE verifying_ids")
  defp get_persons(demand), do: Model.get_unverified_persons(demand)
  defp get_locked_persons(demand, offset), do: Model.get_locked_unverified_persons(demand, offset)
end
