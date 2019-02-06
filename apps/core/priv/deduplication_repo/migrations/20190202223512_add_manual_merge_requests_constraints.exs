defmodule Core.DeduplicationRepo.Migrations.AddManualMergeRequestsConstraints do
  use Ecto.Migration

  def change do
    create(
      unique_index(:manual_merge_requests, [:assignee_id],
        where: "status = 'NEW'",
        name: :manual_merge_requests_assignee_status_index
      )
    )

    create(
      unique_index(:manual_merge_requests, [:assignee_id, :manual_merge_candidate_id],
        name: :manual_merge_requests_assignee_merge_candidate_index
      )
    )

    execute(
      """
      CREATE FUNCTION check_postponed_manual_merge_requests_count()
      RETURNS trigger AS $$
      BEGIN
        LOCK TABLE manual_merge_requests IN SHARE ROW EXCLUSIVE MODE;

        PERFORM FROM manual_merge_requests
        WHERE assignee_id = NEW.assignee_id AND status = 'POSTPONE'
        HAVING count(*) < current_setting('manual_merge_requests.max_postponed')::bigint;

        IF NOT FOUND THEN
          RAISE check_violation USING
            MESSAGE = 'Postponed merge requests limit exceeded for assignee with ID ' || NEW.assignee_id,
            CONSTRAINT = 'manual_merge_requests_postponed_count_check';
        END IF;

        RETURN NEW;
      END;
      $$ LANGUAGE plpgsql;
      """,
      """
      DROP FUNCTION check_postponed_manual_merge_requests_count;
      """
    )

    execute(
      """
      CREATE TRIGGER "001_check_postponed_count"
      BEFORE INSERT ON manual_merge_requests
      FOR EACH ROW EXECUTE PROCEDURE check_postponed_manual_merge_requests_count();
      """,
      """
      DROP TRIGGER "001_check_postponed_count" ON manual_merge_requests;
      """
    )
  end
end
