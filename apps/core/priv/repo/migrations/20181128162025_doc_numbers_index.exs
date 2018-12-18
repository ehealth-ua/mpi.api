defmodule Core.Repo.Migrations.AddressIndex do
  use Ecto.Migration

  def change do
    execute("""
    create index if not exists person_documents_number_index on person_documents(regexp_replace(number, '[^[:digit:]]', '', 'g' ), person_id);
    """)
  end
end
