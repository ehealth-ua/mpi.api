defmodule MPI.Repo.Migrations.AddPersonDocuments do
  use Ecto.Migration

  def up do
    create table(:person_documents, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:person_id, :uuid, references: :persons, type: :uuid)
      add(:type, :string)
      add(:number, :string)
      add(:issued_at, :string)
      add(:expiration_date, :string)
      add(:issued_by, :string)
      timestamps(type: :utc_datetime)
    end

    create(index(:person_documents, [:person_id]))
  end

  def down do
    drop(table(:person_documents))
  end
end
