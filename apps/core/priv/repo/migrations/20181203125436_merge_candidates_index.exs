defmodule Core.Repo.Migrations.MergeCandidatesIndex do
  use Ecto.Migration

  @disable_ddl_transaction true
  def change do
    alter table(:merge_candidates) do
      add(:score, :float)
    end

    create(index(:merge_candidates, [:master_person_id], concurrently: true))
    create(index(:merge_candidates, [:person_id], concurrently: true))

    create table(:verified_ts) do
      timestamps(type: :utc_datetime_usec)
    end

    create table(:verifying_ids, primary_key: false) do
      add(:id, :uuid, primary_key: true)
    end

    create(index(:merge_candidates, [:score]))
    create(index(:merge_candidates, [:status, :score, :person_id]))

    execute("""
    create rule max_updated_at_rule as on update to verified_ts where NEW.updated_at < OLD.updated_at do instead nothing;
    """)
  end
end
