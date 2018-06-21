defmodule MPI.Repo.Migrations.AddPersonPhones do
  use Ecto.Migration

  def up do
    create table(:person_phones, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:person_id, :uuid, references: :persons)
      add(:number, :string)
      add(:type, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:person_phones, [:person_id]))
  end

  def down do
    drop(table(:person_phones))
  end
end
