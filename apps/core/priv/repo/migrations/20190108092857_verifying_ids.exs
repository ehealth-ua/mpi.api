defmodule Core.Repo.Migrations.VerifyingIds do
  use Ecto.Migration

  def change do
    create table(:verifying_ids, primary_key: false) do
      add(:id, :uuid, primary_key: true)
    end
  end
end
