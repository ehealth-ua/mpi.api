defmodule MPI.Repo.Migrations.PublishPersonEvents do
  use Ecto.Migration

  alias MPI.Kafka.Producer
  alias MPI.Person
  alias MPI.Repo
  import Ecto.Query

  @disable_ddl_transaction true

  def change do
    Application.ensure_all_started(:kafka_ex)
    publish_events(0)
  end

  defp publish_events(offset) do
    persons =
      Person
      |> select([p], [:id, :status])
      |> offset(^offset)
      |> limit(500)
      |> Repo.all()

    Enum.map(persons, fn person ->
      Producer.publish_person_event(person.id, person.status)
    end)

    if Enum.empty?(persons) do
      :ok
    else
      publish_events(offset + 500)
    end
  end
end
