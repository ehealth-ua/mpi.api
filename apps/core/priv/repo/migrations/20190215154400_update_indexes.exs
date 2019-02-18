defmodule Core.Repo.Migrations.UpdateIndexes do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    execute("create index CONCURRENTLY if not exists persons_birth_date_index on persons(birth_date);")
    
    execute("drop index if exists persons_actor_idx;")
    execute("drop index if exists person_documents_inserted_at_index;")
    execute("drop index if exists persons_is_active_status_birth_date_tax_id_index;")
  end
end
