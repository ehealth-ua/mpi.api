defmodule MPI.Repo.Migrations.AddInsertedAtIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  @schemas [:person_documents, :person_phones, :persons]
  def up do
    Enum.each(@schemas, fn shemaname -> create(index(shemaname, [:inserted_at], concurrently: true)) end)
  end

  def down do
    Enum.each(@schemas, fn shemaname -> drop(index(shemaname, [:inserted_at], concurrently: true)) end)
  end
end
