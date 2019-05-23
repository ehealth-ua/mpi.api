defmodule Core.Repo.Migrations.UpgradePersonAuthenticationMethodsIndexes do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    execute("CREATE INDEX CONCURRENTLY IF NOT EXISTS phone_number_idx ON person_authentication_methods (phone_number);")
    execute("DROP INDEX IF EXISTS persons_authentication_methods_jsonb_path_ops_index;")
  end
end
