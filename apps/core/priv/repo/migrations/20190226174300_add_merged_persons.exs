defmodule Core.Repo.Migrations.AddMergedPersons do
  use Ecto.Migration

  def change do
    create table(:merged_pairs, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:master_person_id, :uuid)
      add(:merge_person_id, :uuid)
      timestamps(type: :utc_datetime)
    end

    create(index(:merged_pairs, [:master_person_id]))
    create(index(:merged_pairs, [:merge_person_id]))
  end
end
