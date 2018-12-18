defmodule Core.Repo.Migrations.ChangePersonDocumentsTypeNumberIndex do
  use Ecto.Migration

  def change do
    execute("""
    DROP INDEX IF EXISTS person_documents_type_number_index;
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS person_documents_type_lower_number_index ON person_documents (
      type,
      lower(number)
    );
    """)
  end
end
