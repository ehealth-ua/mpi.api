defmodule MPI.Repo.Migrations.AddInsertedAtIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    alter table(:person_documents) do
      modify(:type, :text)
      modify(:issued_by, :text)
      modify(:number, :text)
    end
  end
end
