defmodule Core.Repo.Migrations.AddNewColumnsToPersonUpdates do
  use Ecto.Migration

  def change do
    alter table(:person_updates) do
      add(:inserted_by, :uuid)
      add(:inserted_at, :utc_datetime)
    end
  end
end
