defmodule MPI.Repo.Migrations.RemovePersonsDocumentsAndPhonesFields do
  use Ecto.Migration

  def change do
    alter table(:persons) do
      remove :documents
      remove :phones
    end
  end
end
