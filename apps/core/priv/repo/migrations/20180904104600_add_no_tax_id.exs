defmodule Core.Repo.Migrations.AddNoTaxId do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    alter table(:persons) do
      add(:no_tax_id, :boolean, null: false, default: false)
    end
  end
end
