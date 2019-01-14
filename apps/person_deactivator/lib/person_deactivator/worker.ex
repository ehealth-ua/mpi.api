defmodule PersonDeactivator.Worker do
  @moduledoc false
  use Confex, otp_app: :deduplication
  use GenServer
  require Logger

  @behaviour PersonDeactivator.Behaviours.WorkerBehaviour
  @worker Application.get_env(:person_deactivator, :worker)

  def start_link do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    @worker.run_deactivation()
    {:ok, pid}
  end

  @impl true
  def init(state) do
    {:ok, state}
  end

  @impl true
  def handle_info(:start, state) do
    PersonDeactivator.deactivate_persons()
    @worker.stop_application()
    {:noreply, state}
  end

  def handle_info(_signal, state) do
    {:noreply, state}
  end

  @impl true
  def run_deactivation do
    send(__MODULE__, :start)
  end

  @impl true
  def stop_application do
    Logger.info("Stop application")
    System.halt(0)
  end
end
