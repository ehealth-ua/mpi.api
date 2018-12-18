defmodule Core.Repo.Migrations.TaxIdIndex do
  use Ecto.Migration

  def change do
    execute("""
    create index if not exists persons_tax_id_index on persons(tax_id);
    """)
  end
end
