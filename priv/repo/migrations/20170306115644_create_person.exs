defmodule Mpi.Repo.Migrations.CreateMpi.Person do
  use Ecto.Migration

  def change do
    create table(:persons, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :second_name, :string
      add :birth_date, :date, null: false
      add :gender, :string, null: false
      add :email, :string
      add :tax_id, :string
      add :national_id, :string
      add :death_date, :date
      add :is_active, :boolean, default: true
      add :documents, :map
      add :addresses, :map
      add :phones, :map
      add :history, :map
      add :inserted_by, :string, null: false
      add :updated_by, :string, null: false

      timestamps(type: :utc_datetime)
    end

    create table(:persons_hist, primary_key: false) do
      add :id, :uuid, primary_key: true
      add :first_name, :string, null: false
      add :last_name, :string, null: false
      add :second_name, :string
      add :birth_date, :date, null: false
      add :gender, :string, null: false
      add :email, :string
      add :tax_id, :string
      add :national_id, :string
      add :death_date, :date
      add :is_active, :boolean, default: true
      add :documents, :map
      add :addresses, :map
      add :phones, :map
      add :history, :map
      add :inserted_by, :string, null: false
      add :updated_by, :string, null: false

      timestamps(type: :utc_datetime)
    end
  end
end
