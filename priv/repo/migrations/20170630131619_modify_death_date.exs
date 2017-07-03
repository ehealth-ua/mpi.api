defmodule MPI.Repo.Migrations.ModifyDeathDate do
  use Ecto.Migration

  def change do
    alter table(:persons) do
      modify :death_date, :date, null: true
    end
  end
end
