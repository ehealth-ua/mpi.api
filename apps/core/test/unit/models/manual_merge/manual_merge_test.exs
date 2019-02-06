defmodule Core.Unit.ManualMergeTest do
  use Core.ModelCase, async: false

  import Core.Factory
  alias Core.ManualMerge
  alias Core.ManualMergeRequest
  alias Core.ManualMergeCandidate
  alias Ecto.UUID

  @merge ManualMergeRequest.status(:merge)
  @split ManualMergeRequest.status(:split)
  @trash ManualMergeRequest.status(:trash)
  @postpone ManualMergeRequest.status(:postpone)
  @new ManualMergeCandidate.status(:new)
  @processed ManualMergeCandidate.status(:processed)
  @auto_merge ManualMergeCandidate.status_reason(:auto_merge)

  describe "create manual merge request" do
    test "successful" do
      actor_id = UUID.generate()
      %{id: merge_candidate_id} = insert(:deduplication, :manual_merge_candidate)

      params = %{
        assignee_id: UUID.generate(),
        manual_merge_candidate_id: merge_candidate_id
      }

      assert {:ok, %ManualMergeRequest{manual_merge_candidate_id: merge_candidate_id}} =
               ManualMerge.create(%ManualMergeRequest{}, params, actor_id)
    end
  end

  describe "process merge request" do
    setup do
      actor_id = UUID.generate()
      {:ok, actor_id: actor_id}
    end

    test "request not found", %{actor_id: actor_id} do
      assert {:error, {:not_found, "Manual Merge Request not found"}} =
               ManualMerge.process_merge_request(actor_id, @merge, actor_id)
    end

    test "invalid status transition", %{actor_id: actor_id} do
      %{id: id, manual_merge_candidate: candidate} =
        insert(:deduplication, :manual_merge_request, assignee_id: actor_id)

      assert {:error, {:conflict, "Incorrect transition status"}} =
               ManualMerge.process_merge_request(id, @new, actor_id)

      assert %{decision: nil, status: @new} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "invalid assignee", %{actor_id: actor_id} do
      %{id: id, manual_merge_candidate: candidate} = insert(:deduplication, :manual_merge_request)

      {:error, {:forbidden, "Current client is not allowed to access this resource"}} =
        ManualMerge.process_merge_request(id, @merge, actor_id)

      assert %{decision: nil, status: @new} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "set postpone status", %{actor_id: actor_id} do
      %{id: id, manual_merge_candidate: candidate} =
        insert(:deduplication, :manual_merge_request, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{status: @postpone}} = ManualMerge.process_merge_request(id, @postpone, actor_id)
      assert %{decision: nil, status: @new} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "set merge status, request created, quorum NOT obtained", %{actor_id: actor_id} do
      candidate = insert(:deduplication, :manual_merge_candidate, assignee_id: actor_id)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: candidate, assignee_id: actor_id)

      assert {:ok, merge_request} = ManualMerge.process_merge_request(id, @merge, actor_id, "some comment")
      assert %ManualMergeRequest{} = merge_request
      assert "some comment" == merge_request.comment

      assert %{decision: nil, status: @new, assignee_id: nil} =
               ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "set MERGE status, quorum obtained, candidate processed, related candidates auto merged", %{actor_id: actor_id} do
      candidate = insert(:deduplication, :manual_merge_candidate, assignee_id: actor_id)

      related_candidate =
        insert(:deduplication, :manual_merge_candidate,
          person_id: candidate.master_person_id,
          master_person_id: candidate.person_id,
          assignee_id: actor_id
        )

      insert_list(2, :deduplication, :manual_merge_request, status: @merge, manual_merge_candidate: candidate)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: candidate, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{}} = ManualMerge.process_merge_request(id, @merge, actor_id)

      assert %{decision: @merge, status: @processed, assignee_id: nil} =
               ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)

      assert %{decision: @merge, status: @processed, assignee_id: nil, status_reason: @auto_merge} =
               ManualMerge.get_by_id(ManualMergeCandidate, related_candidate.id)
    end

    test "set TRASH status, quorum obtained, candidate processed", %{actor_id: actor_id} do
      candidate = insert(:deduplication, :manual_merge_candidate)
      insert_list(2, :deduplication, :manual_merge_request, status: @merge, manual_merge_candidate: candidate)
      insert_list(2, :deduplication, :manual_merge_request, status: @trash, manual_merge_candidate: candidate)
      insert_list(2, :deduplication, :manual_merge_request, status: @split, manual_merge_candidate: candidate)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: candidate, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{}} = ManualMerge.process_merge_request(id, @trash, actor_id)
      assert %{decision: @trash, status: @processed} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end

    test "set SPLIT status, quorum obtained, candidate processed", %{actor_id: actor_id} do
      candidate = insert(:deduplication, :manual_merge_candidate)
      insert_list(2, :deduplication, :manual_merge_request, status: @split, manual_merge_candidate: candidate)

      %{id: id} =
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: candidate, assignee_id: actor_id)

      assert {:ok, %ManualMergeRequest{}} = ManualMerge.process_merge_request(id, @split, actor_id)
      assert %{decision: @split, status: @processed} = ManualMerge.get_by_id(ManualMergeCandidate, candidate.id)
    end
  end
end
