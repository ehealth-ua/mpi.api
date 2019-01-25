defmodule Core.Repo.Migrations.TaxIdIndex do
  use Ecto.Migration

  def change do
    execute("""
    create index if not exists persons_tax_id_index on persons(tax_id);
    """)

    execute("""
    create index if not exists person_documents_number_index on person_documents(
    regexp_replace(number, '[^[:digit:]]', '', 'g' ), person_id);
    """)

    execute("""
    CREATE INDEX IF NOT EXISTS person_documents_type_lower_number_index ON person_documents (
      type,
      lower(number)
    );
    """)

    execute("""
    DROP INDEX IF EXISTS person_documents_type_number_index;
    """)

    execute("""
    create index if not exists persons_updated_at_index on persons(updated_at);
    """)
  end
end
