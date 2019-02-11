defmodule Deduplication.Producer do
  @moduledoc """
  produce unverified persons
  """
  use Confex, otp_app: :deduplication
  use GenStage

  alias Core.Repo
  alias Deduplication.V2.Model
  alias Ecto.Adapters.SQL

  require Logger

  def start_link(%{id: id}) do
    {:ok, pid} = GenStage.start_link(__MODULE__, %{}, name: id, id: id)
    send(pid, :refresh)
    {:ok, pid}
  end

  @impl true
  def init(%{} = _state) do
    {:producer, %{mode: config()[:mode], offset: 0}, []}
  end

  @impl true
  def handle_info(:refresh, state) do
    refersh_stat()
    Process.send_after(self(), :refresh, config()[:refresh_timeout])
    {:noreply, [], state}
  end

  @impl true
  def handle_demand(demand, %{mode: :new} = state) when demand > 0 do
    {:noreply, unverified_persons(demand), state}
  end

  def handle_demand(demand, %{mode: mode, offset: offset}) when demand > 0 do
    locked_persons = Model.get_locked_unverified_persons(demand, offset)
    continue? = not Model.no_locked_pesons?()

    # The order of cond is nessesary, first check does locked_persons is not empty
    cond do
      not Enum.empty?(locked_persons) ->
        {:noreply, locked_persons, %{mode: mode, offset: offset + demand}}

      continue? ->
        locked_persons = Model.get_locked_unverified_persons(demand, 0)
        {:noreply, locked_persons, %{mode: mode, offset: demand}}

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
    Model.get_unverified_persons(demand)
  end

  defp refersh_stat do
    SQL.query!(Repo, "vacuum ANALYZE verifying_ids")
  end
end
