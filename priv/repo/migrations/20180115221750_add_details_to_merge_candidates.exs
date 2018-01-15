defmodule MPI.Repo.Migrations.AddDetailsToMergeCandidates do
  use Ecto.Migration

  def change do
    alter table(:merge_candidates) do
      add :config, :map
      add :details, :map
    end
  end
end
