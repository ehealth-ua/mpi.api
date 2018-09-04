defmodule Core.Repo.Migrations.DropPersonDocumentIndex do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    drop(index(:persons, [:documents], concurrently: true))
  end
end
