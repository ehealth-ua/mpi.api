defmodule Core.DeduplicationRepo.Migrations.CreateAuditLog do
  use Ecto.Migration

  def change do
    create table(:audit_log_deduplication, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:actor_id, :text, null: false)
      add(:resource, :text, null: false)
      add(:resource_id, :text, null: false)
      add(:changeset, :map, null: false)

      timestamps(type: :utc_datetime_usec, updated_at: false)
    end
  end
end
