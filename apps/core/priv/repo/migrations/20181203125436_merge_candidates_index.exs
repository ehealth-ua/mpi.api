defmodule Core.Repo.Migrations.MergeCandidatesIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    create(index(:merge_candidates, [:master_person_id], concurrently: true))
    create(index(:merge_candidates, [:person_id], concurrently: true))
  end
end
