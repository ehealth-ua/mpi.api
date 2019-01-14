defmodule Core.Repo.Migrations.AddScore do
  use Ecto.Migration

  def change do
    alter table(:merge_candidates) do
      add(:score, :float)
    end

    create(index(:merge_candidates, [:score]))
    create(index(:merge_candidates, [:status, :score, :person_id]))
  end
end
