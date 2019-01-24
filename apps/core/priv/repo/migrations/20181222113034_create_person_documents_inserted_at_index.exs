defmodule Core.Repo.Migrations.CreatePersonDocumentsInsertedAtIndex do
  use Ecto.Migration

  def change do
    create_if_not_exists(index(:person_documents, [:inserted_at], name: "person_documents_inserted_at_index"))
  end
end
