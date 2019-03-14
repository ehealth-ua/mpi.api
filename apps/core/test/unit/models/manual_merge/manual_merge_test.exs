defmodule Core.Unit.ManualMergeTest do
  use Core.ModelCase, async: false

  import Core.Factory

  alias Core.{ManualMerge, ManualMergeCandidate, ManualMergeRequest}
  alias Ecto.{Changeset, UUID}

  @new ManualMergeCandidate.status(:new)
  @postpone ManualMergeRequest.status(:postpone)
  @merge ManualMergeRequest.status(:merge)

  describe "assign merge candidate" do
    test "success" do
      merge_candidates = insert_list(3, :deduplication, :manual_merge_candidate)

      for {merge_candidate, merge_requests_count} <- merge_candidates |> Enum.reverse() |> Enum.with_index(),
          i <- 0..merge_requests_count,
          i > 0 do
        insert(:deduplication, :manual_merge_request, manual_merge_candidate: merge_candidate)
      end

      %{id: expected_merge_candidate_id} = hd(merge_candidates)
      actor_id = UUID.generate()

      assert {:ok,
              %ManualMergeRequest{
                assignee_id: ^actor_id,
                status: @new,
                manual_merge_candidate: %ManualMergeCandidate{
                  id: ^expected_merge_candidate_id
                }
              }} = ManualMerge.assign_merge_candidate(actor_id)
    end

    test "fail when all available merge candidates are assigned" do
      insert_list(2, :deduplication, :manual_merge_candidate, assignee_id: UUID.generate())
      actor_id = UUID.generate()

      assert {:error, {:not_found, _}} = ManualMerge.assign_merge_candidate(actor_id)
    end

    test "fail when all available merge candidates are processed" do
      actor_id = UUID.generate()

      merge_candidates = insert_list(2, :deduplication, :manual_merge_candidate)

      for merge_candidate <- merge_candidates do
        insert(:deduplication, :manual_merge_request,
          manual_merge_candidate: merge_candidate,
          assignee_id: actor_id,
          status: @postpone
        )
      end

      insert(:deduplication, :manual_merge_request,
        manual_merge_candidate: hd(merge_candidates),
        status: @merge
      )

      assert {:error, {:not_found, _}} = ManualMerge.assign_merge_candidate(actor_id)
    end

    test "fail when new request already assigned" do
      insert_list(2, :deduplication, :manual_merge_candidate)

      actor_id = UUID.generate()

      insert(:deduplication, :manual_merge_request, assignee_id: actor_id, status: @new)

      assert {:error,
              %Changeset{
                errors: [assignee_id: {"new request is already present", _}],
                valid?: false
              }} = ManualMerge.assign_merge_candidate(actor_id)
    end

    test "fail when postponed requests limit exceeded" do
      actor_id = UUID.generate()

      insert(:deduplication, :manual_merge_candidate)

      insert_list(5, :deduplication, :manual_merge_request,
        assignee_id: actor_id,
        status: @postpone
      )

      assert {:error,
              %Changeset{
                errors: [assignee_id: {"postponed requests limit exceeded", _}],
                valid?: false
              }} = ManualMerge.assign_merge_candidate(actor_id)
    end
  end
end
