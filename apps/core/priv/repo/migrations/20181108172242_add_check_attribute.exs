defmodule Core.Repo.Migrations.AddCheckAttribute do
  use Ecto.Migration

  @disable_ddl_transaction true

  def change do
    alter table(:persons) do
      add(:merge_verified, :boolean)
    end

    execute("""
    create index if not exists persons_unmerged_index on persons(inserted_at DESC) where merge_verified IS NULL;
    """)
  end
end
