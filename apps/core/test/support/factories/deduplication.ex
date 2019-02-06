defmodule Core.Factories.Deduplication do
  @moduledoc """
  This module lists factories, a mean suitable
  for tests that involve preparation of DB data
  """
  defmacro __using__(_opts) do
    quote do
      alias Ecto.UUID
      alias Core.ManualMergeCandidate
      alias Core.ManualMergeRequest

      def manual_merge_candidate_factory do
        %ManualMergeCandidate{
          status: ManualMergeCandidate.status(:new),
          status_reason: nil,
          decision: nil,
          assignee_id: nil,
          person_id: UUID.generate(),
          master_person_id: UUID.generate(),
          merge_candidate_id: UUID.generate()
        }
      end

      def manual_merge_request_factory do
        %ManualMergeRequest{
          status: ManualMergeRequest.status(:new),
          comment: nil,
          assignee_id: UUID.generate(),
          manual_merge_candidate: build(:manual_merge_candidate)
        }
      end
    end
  end
end
