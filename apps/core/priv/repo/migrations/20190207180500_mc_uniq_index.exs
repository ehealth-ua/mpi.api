defmodule Core.Repo.Migrations.MergeCandidatesUniqueIndex do
  use Ecto.Migration
  @disable_ddl_transaction true

  def change do
    execute("""
    create unique index CONCURRENTLY if not exists merge_candidates_master_person_person_index on merge_candidates (master_person_id, person_id);
    """)
  end
end
