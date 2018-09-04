defmodule Core.Repo.Migrations.AddFieldsToPersons do
  use Ecto.Migration

  def change do
    alter table(:persons) do
      add(:archived_at, :date, null: true)
      add(:invalid_tax_id, :boolean, default: false)
      add(:preferred_way_communication, :string, null: true)
    end
  end
end
