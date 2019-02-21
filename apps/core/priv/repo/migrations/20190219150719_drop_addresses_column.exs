defmodule Core.Repo.Migrations.DropAddressesColumn do
  use Ecto.Migration

  def change do
    execute("ALTER TABLE persons DROP COLUMN IF EXISTS addresses;")
  end
end
