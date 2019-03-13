defmodule Core.Repo.Migrations.VerifyingIdsIsComopleteIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    execute("CREATE INDEX CONCURRENTLY IF NOT EXISTS verifying_ids_idx_is_completed ON verifying_ids(is_complete);")
  end
end
