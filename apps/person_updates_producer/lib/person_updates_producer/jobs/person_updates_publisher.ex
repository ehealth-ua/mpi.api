defmodule PersonUpdatesProducer.Jobs.PersonUpdatesPublisher do
  @moduledoc """
  Push persins updates to kafka
  """
  use Confex, otp_app: :person_updates_producer

  alias Core.PersonUpdate
  alias Core.Repo
  import Ecto.Query
  require Logger

  @kafka_producer Application.get_env(:person_updates_producer, :kafka)[:producer]
  def run do
    PersonUpdate
    |> limit(^config()[:batch_size])
    |> Repo.all()
    |> publish_updates()
  end

  defp publish_updates([]), do: :ok

  defp publish_updates(updates) do
    Enum.each(updates, fn %PersonUpdate{
                            person_id: id,
                            status: status,
                            updated_by: updated_by,
                            inserted_by: inserted_by,
                            updated_at: updated_at,
                            inserted_at: inserted_at
                          } ->
      :ok = @kafka_producer.publish_person_event(id, status, updated_by, inserted_by, updated_at, inserted_at)
    end)

    ids = Enum.map(updates, & &1.id)
    Repo.delete_all(PersonUpdate |> where([pu], pu.id in ^ids))
    Logger.info("Processed #{Enum.count(updates)} person updates")
  end
end
