defmodule Deduplication.Worker do
  @moduledoc false
  use Confex, otp_app: :deduplication
  use GenServer

  alias Deduplication.V2.Match
  alias Deduplication.V2.Model

  require Logger

  @behaviour Deduplication.Behaviours.WorkerBehaviour
  @worker Application.get_env(:deduplication, :worker)

  def start_link do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil, name: __MODULE__)
    @worker.run_deduplication()
    {:ok, pid}
  end

  @impl true
  def init(_state) do
    limit = config()[:deduplication_persons_limit]
    tasks = config()[:parallel_tasks]

    {:ok, %{limit: limit, tasks: tasks}}
  end

  @impl true
  def handle_info(:run, %{limit: limit, tasks: tasks} = state) do
    n = max(tasks - 1, 0)

    updates_done =
      0..n
      |> Task.async_stream(
        fn i ->
          Match.deduplicate_person(limit, limit * i)
        end,
        timeout: 1_000_000
      )
      |> Model.async_stream_filter()
      |> MapSet.new()
      |> MapSet.to_list()

    if updates_done == [0] or updates_done == [] do
      Logger.info("Deduplication done")
      @worker.stop_application()
    else
      send(__MODULE__, :run)
    end

    {:noreply, state}
  end

  @impl true
  def stop_application do
    Logger.info("Stop application")
    System.halt(0)
  end

  @impl true
  def run_deduplication do
    send(__MODULE__, :run)
  end
end
