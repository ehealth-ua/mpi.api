defmodule MPI.Repo.Migrations.AddInsertedAtIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    create(index(:persons, [:inserted_at], concurrently: true))
  end

  def down do
    drop(index(:persons, [:inserted_at], concurrently: true))
  end
end
