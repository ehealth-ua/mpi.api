defmodule Core.Repo.Migrations.AddressesDropUnusedColumns do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    execute("ALTER TABLE person_addresses DROP COLUMN IF EXISTS person_first_name;")
    execute("ALTER TABLE person_addresses DROP COLUMN IF EXISTS person_last_name;")
    execute("ALTER TABLE persons DROP COLUMN IF EXISTS merged_ids;")
  end
end
