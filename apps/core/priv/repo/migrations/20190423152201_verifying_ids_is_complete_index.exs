defmodule Core.Repo.Migrations.VerifyingIdsIsComopleteIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    execute("""
    CREATE UNIQUE INDEX CONCURRENTLY if not exists  "persons_uniq_index" ON persons (
      tax_id,
      birth_date,
      last_name,
      first_name,
      second_name
    )
    WHERE status = 'active';
    """)

    execute("""
    DROP INDEX CONCURRENTLY IF EXISTS persons_first_name_last_name_second_name_tax_id_birth_date_inde;
    """)

    execute("""
    CREATE INDEX CONCURRENTLY if not exists "auth_method_search_idx" ON persons (
      birth_date,
      lower(last_name),
      lower(first_name),
      lower(second_name)
    );
    """)

    execute("DROP INDEX CONCURRENTLY IF EXISTS auth_method_search_index;")
  end
end
