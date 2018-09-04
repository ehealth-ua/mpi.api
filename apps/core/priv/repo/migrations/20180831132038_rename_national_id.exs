defmodule Core.Repo.Migrations.RenameNationaIdUnzr do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    rename(table(:persons), :national_id, to: :unzr)
  end
end
