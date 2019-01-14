defmodule Core.Repo.Migrations.ChangeVerifiedFlag do
  use Ecto.Migration

  def change do
    execute("""
    create index if not exists persons_inserted_at_index on persons(inserted_at desc);
    """)

    create table(:verified_ts) do
      timestamps(type: :utc_datetime)
    end

    execute("""
    insert into verified_ts select 0, '1970-01-01 00:00:00', now();
    """)

    execute("""
    create rule max_inserted_at_rule as  on update to verified_ts where NEW.inserted_at < OLD.inserted_at do instead nothing;
    """)

    alter table(:persons) do
      remove(:merge_verified)
    end
  end
end
