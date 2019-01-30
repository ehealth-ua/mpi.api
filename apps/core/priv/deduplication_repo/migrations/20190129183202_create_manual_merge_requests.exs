defmodule Core.DeduplicationRepo.Migrations.CreateManualMergeRequests do
  use Ecto.Migration

  def change do
    create table(:manual_merge_requests, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:status, :string, null: false)
      add(:comment, :string, default: nil)
      add(:assignee_id, :uuid, null: false)
      add(:manual_merge_candidate_id, references(:manual_merge_candidates, type: :uuid), null: false)

      timestamps(type: :utc_datetime)
    end
  end
end
