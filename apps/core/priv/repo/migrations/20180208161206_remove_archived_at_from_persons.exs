defmodule Core.Repo.Migrations.RemoveArchivedAtFromPersons do
  use Ecto.Migration

  def change do
    alter table(:persons) do
      remove(:archived_at)
    end
  end
end
