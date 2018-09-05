defmodule Deduplication.Worker do
  @moduledoc false

  use GenServer
  alias Deduplication.Match
  use Confex, otp_app: :deduplication

  @behaviour Deduplication.Behaviours.WorkerBehaviour
  @worker Application.get_env(:deduplication, :worker)

  def start_link do
    GenServer.start_link(__MODULE__, nil)
  end

  @impl true
  def init(state) do
    Process.send_after(self(), :run, 10)
    {:ok, state}
  end

  @impl true
  def handle_info(:run, state) do
    Match.run()
    @worker.stop_application()
    {:stop, :normal, state}
  end

  def stop_application do
    System.halt(0)
  end
end
