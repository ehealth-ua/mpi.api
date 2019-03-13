defmodule Core.Repo.Migrations.VerifyingIdsAddSatus do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    execute("ALTER TABLE verifying_ids ADD COLUMN IF NOT EXISTS is_complete BOOLEAN;")
    execute("CREATE INDEX CONCURRENTLY IF NOT EXISTS verifying_ids_idx_is_completed ON verifying_ids(is_complete);")
  end
end
