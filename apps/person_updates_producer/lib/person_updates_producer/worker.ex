defmodule PersonUpdatesProducer.Worker do
  @moduledoc false

  use GenServer
  use Confex, otp_app: :person_updates_producer

  import Ecto.Query
  alias Core.PersonUpdate
  alias Core.Repo
  alias PersonUpdatesProducer.Kafka.Producer
  require Logger

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
    limit = config()[:batch_size]
    updates = PersonUpdate |> limit(^limit) |> Repo.all()

    if Enum.empty?(updates) do
      pid = Process.whereis(PersonUpdatesProducer.Supervisor)
      Process.exit(pid, :normal)
      {:stop, :normal, state}
    else
      Enum.each(updates, fn %PersonUpdate{person_id: id, status: status, updated_by: updated_by} ->
        :ok = Producer.publish_person_event(id, status, updated_by)
      end)

      ids = Enum.map(updates, &Map.get(&1, :id))
      Repo.delete_all(PersonUpdate |> where([pu], pu.id in ^ids))
      Logger.info("Processed #{Enum.count(updates)} person updates")
      Process.send_after(self(), :run, 10)

      {:noreply, state}
    end
  end
end
