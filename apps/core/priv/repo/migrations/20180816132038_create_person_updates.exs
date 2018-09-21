defmodule Core.Repo.Migrations.CreatePersonUpdates do
  use Ecto.Migration

  def change do
    create table(:person_updates) do
      add(:person_id, :uuid)
      add(:updated_by, :uuid)
      add(:updated_at, :utc_datetime)
      add(:status, :string)
    end
  end
end
