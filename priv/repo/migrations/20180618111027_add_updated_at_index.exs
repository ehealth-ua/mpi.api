defmodule MPI.Repo.Migrations.AddInsertedAtIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def up do
    create(index(:persons, [:updated_at], concurrently: true))
    create(index(:person_documents, [:updated_at], concurrently: true))
  end

  def down do
    drop(index(:persons, [:updated_at], concurrently: true))
    drop(index(:person_documents, [:updated_at], concurrently: true))
  end
end
