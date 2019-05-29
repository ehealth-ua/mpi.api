defmodule Core.Repo.Migrations.AddMergedIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    execute("""
    CREATE INDEX CONCURRENTLY IF NOT EXISTS merged_pairs_inserted_at_idx ON merged_pairs(inserted_at);
    """)
  end
end
