defmodule Core.Repo.Migrations.PublishPersonEvents do
  @moduledoc false

  use Ecto.Migration

  alias Core.Person
  alias Core.PersonUpdate
  alias Core.Repo
  import Ecto.Query

  @disable_ddl_transaction true

  def change do
    publish_events(0)
  end

  defp publish_events(offset) do
    persons =
      Person
      |> select([p], [:id, :status, :updated_by, :updated_at])
      |> offset(^offset)
      |> limit(500)
      |> Repo.all()

    Enum.each(persons, fn person ->
      Repo.insert(%PersonUpdate{
        person_id: person.id,
        updated_by: person.updated_by,
        updated_at: person.updated_at,
        status: person.status
      })
    end)

    if Enum.empty?(persons) do
      :ok
    else
      publish_events(offset + 500)
    end
  end
end
