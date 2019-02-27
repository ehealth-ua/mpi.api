defmodule CandidatesMergerTest do
  use Core.ModelCase, async: false

  import Core.Factory

  alias Core.{DeduplicationRepo, ManualMerge, ManualMergeCandidate, ManualMergeRequest}
  alias Core.ManualMerge.AuditLog
  alias Core.MergeCandidates.API, as: MergeCandidates
  alias Ecto.UUID

  @new ManualMergeCandidate.status(:new)
  @postpone ManualMergeRequest.status(:postpone)
  @merge ManualMergeRequest.status(:merge)
  @split ManualMergeRequest.status(:split)
  @trash ManualMergeRequest.status(:trash)
  @processed ManualMergeCandidate.status(:processed)
  @processed ManualMergeCandidate.status(:processed)
  @auto_merge ManualMergeCandidate.status_reason(:auto_merge)

  setup :verify_on_exit!

  describe "process merge request" do
    setup do
      actor_id = UUID.generate()
      {:ok, actor_id: actor_id}
    end

    test "request not found", %{actor_id: actor_id} do
      assert {:error, {:not_found, "Manual Merge Request not found"}} =
               CandidatesMerger.process_merge_request(actor_id, @merge, actor_id)
    end

    test "invalid status transition", %{actor_id: actor_id} do
      %{id: id, manual_merge_candidate: candidate} =
        insert(:deduplication, :manual_merge_request, assignee_id: actor_id)

      assert {:error, {:conflict, "Incorrect transition status"}} =
               CandidatesMerger.process_merge_request(id, @new, actor_id)

      assert %{decision: nil, status: @new} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "invalid assignee", %{actor_id: actor_id} do
      %{id: id, manual_merge_candidate: candidate} = insert(:deduplication, :manual_merge_request)

      {:error, {:forbidden, "Current client is not allowed to access this resource"}} =
        CandidatesMerger.process_merge_request(id, @merge, actor_id)

      assert %{decision: nil, status: @new} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "set postpone status", %{actor_id: actor_id} do
      %{id: id, manual_merge_candidate: candidate} =
        insert(:deduplication, :manual_merge_request, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{status: @postpone}} =
               CandidatesMerger.process_merge_request(id, @postpone, actor_id)

      assert %{decision: nil, status: @new} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "set merge status, request created, quorum NOT obtained", %{actor_id: actor_id} do
      candidate = insert(:mpi, :merge_candidate, score: 0.86)

      manual_candidate =
        insert(:deduplication, :manual_merge_candidate, assignee_id: actor_id, merge_candidate_id: candidate.id)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_candidate, assignee_id: actor_id)

      assert {:ok, merge_request} = CandidatesMerger.process_merge_request(id, @merge, actor_id, "some comment")
      assert %ManualMergeRequest{} = merge_request
      assert "some comment" == merge_request.comment

      assert %{decision: nil, status: @new, assignee_id: nil} =
               ManualMerge.get_by_id(ManualMergeCandidate, manual_candidate.id)

      assert %{score: 0.86} = MergeCandidates.get_by_id(candidate.id)
    end

    test "set MERGE status, quorum obtained, candidate processed, related candidates auto merged", %{actor_id: actor_id} do
      expect(CandidatesMergerKafkaMock, :publish_person_deactivation_event, fn
        _candidates, _system_user_id, "MANUAL_MERGE" ->
          :ok
      end)

      candidate = insert(:mpi, :merge_candidate)

      manual_candidate =
        insert(:deduplication, :manual_merge_candidate,
          person_id: candidate.master_person_id,
          master_person_id: candidate.person_id,
          assignee_id: actor_id,
          merge_candidate_id: candidate.id
        )

      related_candidate_1 =
        insert(:deduplication, :manual_merge_candidate,
          person_id: insert(:mpi, :person).id,
          master_person_id: manual_candidate.person_id,
          assignee_id: actor_id
        )

      related_candidate_2 =
        insert(:deduplication, :manual_merge_candidate,
          person_id: manual_candidate.person_id,
          master_person_id: insert(:mpi, :person).id,
          assignee_id: actor_id
        )

      insert_list(2, :deduplication, :manual_merge_request, status: @merge, manual_merge_candidate: manual_candidate)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_candidate, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{}} = CandidatesMerger.process_merge_request(id, @merge, actor_id)

      assert %{decision: @merge, status: @processed, assignee_id: nil} =
               ManualMerge.get_by_id(ManualMergeCandidate, manual_candidate.id)

      # Related candidate by :master_person_id
      related_candidate = ManualMerge.get_by_id(ManualMergeCandidate, related_candidate_1.id)
      assert %ManualMergeCandidate{} = related_candidate
      assert @merge == related_candidate.decision
      assert @processed == related_candidate.status
      assert @auto_merge == related_candidate.status_reason
      refute related_candidate.assignee_id

      # Related candidate by :person_id
      related_candidate = ManualMerge.get_by_id(ManualMergeCandidate, related_candidate_2.id)
      assert %ManualMergeCandidate{} = related_candidate
      assert @merge == related_candidate.decision
      assert @processed == related_candidate.status
      assert @auto_merge == related_candidate.status_reason
      refute related_candidate.assignee_id

      manual_candidate = ManualMerge.get_by_id(ManualMergeCandidate, manual_candidate.id)
      refute manual_candidate.status_reason

      # 4 entries in Audit log for:
      # - mark Manual Merge Request as MERGE
      # - mark Manual Merge Candidate as MERGE
      # - mark 2 related Manual Merge Candidates as AUTO-MERGE
      assert 4 == length(DeduplicationRepo.all(AuditLog))
    end

    test "set POSTPONE status, quorum obtained, candidate NOT processed", %{actor_id: actor_id} do
      candidate = insert(:mpi, :merge_candidate)

      manual_candidate =
        insert(:deduplication, :manual_merge_candidate,
          person_id: candidate.master_person_id,
          master_person_id: candidate.person_id,
          assignee_id: actor_id,
          merge_candidate_id: candidate.id
        )

      insert_list(5, :deduplication, :manual_merge_request, status: @postpone, manual_merge_candidate: manual_candidate)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_candidate, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{}} = CandidatesMerger.process_merge_request(id, @postpone, actor_id)
      manual_merge = ManualMerge.get_by_id(ManualMergeCandidate, manual_candidate.id)
      refute manual_merge.decision
      refute manual_merge.assignee_id
      assert @new == manual_merge.status
    end

    test "rollback transaction when failed create message in Kafka for person deactivation", %{actor_id: actor_id} do
      expect(CandidatesMergerKafkaMock, :publish_person_deactivation_event, fn _candidates, _system_user_id, _ ->
        "something wrong"
      end)

      candidate = insert(:mpi, :merge_candidate)

      manual_candidate =
        insert(:deduplication, :manual_merge_candidate,
          person_id: candidate.master_person_id,
          master_person_id: candidate.person_id,
          assignee_id: actor_id,
          merge_candidate_id: candidate.id
        )

      insert_list(2, :deduplication, :manual_merge_request, status: @merge, manual_merge_candidate: manual_candidate)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_candidate, assignee_id: actor_id)

      assert {:error, _} = CandidatesMerger.process_merge_request(id, @merge, actor_id)

      candidate = ManualMerge.get_by_id(ManualMergeCandidate, manual_candidate.id)
      assert @new == candidate.status
      assert actor_id == candidate.assignee_id
      refute candidate.decision
    end

    test "set TRASH status, quorum obtained, candidate processed", %{actor_id: actor_id} do
      candidate = insert(:deduplication, :manual_merge_candidate)
      insert_list(2, :deduplication, :manual_merge_request, status: @merge, manual_merge_candidate: candidate)
      insert_list(2, :deduplication, :manual_merge_request, status: @trash, manual_merge_candidate: candidate)
      insert_list(2, :deduplication, :manual_merge_request, status: @split, manual_merge_candidate: candidate)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: candidate, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{}} = CandidatesMerger.process_merge_request(id, @trash, actor_id)
      assert %{decision: @trash, status: @processed} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "set SPLIT status, quorum obtained, candidate processed", %{actor_id: actor_id} do
      candidate = insert(:deduplication, :manual_merge_candidate)
      insert_list(2, :deduplication, :manual_merge_request, status: @split, manual_merge_candidate: candidate)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: candidate, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{}} = CandidatesMerger.process_merge_request(id, @split, actor_id)
      assert %{decision: @split, status: @processed} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end
  end
end
