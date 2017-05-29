defmodule MPI.Repo.Migrations.UpdateMpiSchema do
  use Ecto.Migration

  def change do
    alter table(:persons) do
      add :version, :string
      modify :birth_date, :date, null: false
      modify :death_date, :date, null: false
      add :emergency_contact, :map
      add :confidant_person, :map
      add :authentication_methods, :map
      add :secret, :binary
      remove :history
      remove :signature
      add :status, :string
    end
  end
end
