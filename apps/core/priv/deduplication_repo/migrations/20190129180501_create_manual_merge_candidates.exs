defmodule Core.DeduplicationRepo.Migrations.CreateManualMergeCandidates do
  use Ecto.Migration

  def change do
    create table(:manual_merge_candidates, primary_key: false) do
      add(:id, :uuid, primary_key: true)
      add(:status, :text, null: false)
      add(:status_reason, :text, default: nil)
      add(:decision, :text, default: nil)
      add(:assignee_id, :uuid)
      add(:person_id, :uuid, null: false)
      add(:master_person_id, :uuid, null: false)
      add(:merge_candidate_id, :uuid, null: false)

      timestamps(type: :utc_datetime_usec)
    end

    create(unique_index(:manual_merge_candidates, ~w(master_person_id person_id)a))
  end
end
