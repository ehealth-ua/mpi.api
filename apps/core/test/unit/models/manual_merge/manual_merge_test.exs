defmodule Core.Unit.ManualMergeTest do
  use Core.ModelCase, async: false

  import Core.Factory
  alias Core.ManualMerge
  alias Core.ManualMergeRequest
  alias Core.ManualMergeCandidate
  alias Ecto.UUID

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
end
