defmodule Deduplication.Producer do
  @moduledoc """
  produce unverified persons
  """
  use Confex, otp_app: :deduplication
  use GenStage

  alias Deduplication.Model

  require Logger

  def start_link(%{id: id}) do
    __MODULE__
    |> GenStage.start_link(%{}, name: id, id: id)
    |> start()
  end

  @impl true
  def init(_state) do
    Model.store_deduplication_details()
    mode = config()[:mode]
    locked_persons = if mode != :new, do: %{locked_persons: get_locked_persons()}, else: %{}
    state = Map.merge(%{mode: mode}, locked_persons)
    {:producer, state, []}
  end

  @impl true
  def handle_info(:vacuum, state) do
    refresh_stat()
    Process.send_after(self(), :vacuum, config()[:vacuum_refresh_timeout])
    {:noreply, [], state}
  end

  @impl true
  def handle_demand(demand, state) when demand > 0, do: produce_persons(demand, state)
  def handle_demand(_demand, state), do: {:noreply, [], state}

  def produce_persons(demand, %{mode: :new} = state), do: {:noreply, get_persons(demand), state}
  def produce_persons(demand, %{locked_persons: []}), do: produce_persons(demand, %{mode: :new})

  def produce_persons(demand, %{mode: mode, locked_persons: locked_persons}) do
    {locked_persons_on_demand, rest_locked_persons} = Enum.split(locked_persons, demand)
    locked_persons_number = Enum.count(locked_persons_on_demand)

    case mode do
      :locked ->
        {:noreply, locked_persons_on_demand, %{mode: mode, locked_persons: rest_locked_persons}}

      :mixed ->
        if locked_persons_number < demand do
          persons = get_persons(demand - locked_persons_number)
          {:noreply, persons ++ locked_persons_on_demand, %{mode: :new}}
        else
          {:noreply, locked_persons_on_demand, %{mode: mode, locked_persons: rest_locked_persons}}
        end
    end
  end

  defp get_persons(demand), do: Model.get_unverified_persons(demand)
  defp get_locked_persons, do: Model.get_locked_unverified_persons()

  def start({:ok, pid} = worker) do
    if config()[:vacuum_refresh], do: send(pid, :vacuum)
    worker
  end

  defp refresh_stat, do: Model.cleanup_locked_persons()
end
