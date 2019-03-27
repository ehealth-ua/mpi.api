defmodule ManualMerger.RpcTest do
  @moduledoc false

  use Core.ModelCase, async: true

  import Core.Factory
  import Mox

  alias Core.DeduplicationRepo
  alias Core.ManualMergeRequest
  alias Core.ManualMergeCandidate
  alias ManualMerger.Rpc
  alias Ecto.Changeset
  alias Ecto.UUID

  @status_new ManualMergeRequest.status(:new)
  @status_merge ManualMergeRequest.status(:merge)
  @status_split ManualMergeRequest.status(:split)
  @status_postpone ManualMergeRequest.status(:postpone)

  setup :verify_on_exit!

  describe "search_manual_merge_requests/3" do
    setup do
      person = insert(:mpi, :person)
      master_person = insert(:mpi, :person)
      merge_candidate = insert(:mpi, :merge_candidate, person: person, master_person: master_person)

      %{merge_candidate: merge_candidate}
    end

    test "success with filter params", %{
      merge_candidate: %{id: merge_candidate_id, person: person, master_person: master_person}
    } do
      manual_merge_candidate = insert(:deduplication, :manual_merge_candidate, merge_candidate_id: merge_candidate_id)

      insert_list(2, :deduplication, :manual_merge_request,
        manual_merge_candidate: manual_merge_candidate,
        status: @status_merge
      )

      insert_list(4, :deduplication, :manual_merge_request,
        manual_merge_candidate: manual_merge_candidate,
        status: @status_new
      )

      insert_list(8, :deduplication, :manual_merge_request)

      assert {:ok, [resp_entity | _] = resp_entities} =
               Rpc.search_manual_merge_requests([{:status, :equal, @status_merge}], [desc: :inserted_at], {0, 10})

      assert 2 == length(resp_entities)

      assert master_person.id == get_in(resp_entity, [:manual_merge_candidate, :merge_candidate, :master_person, :id])
      assert person.id == get_in(resp_entity, [:manual_merge_candidate, :merge_candidate, :person, :id])
    end

    test "success on empty response" do
      assert {:ok, []} == Rpc.search_manual_merge_requests([{:status, :equal, @status_new}], [], {0, 10})
    end
  end

  describe "assign_manual_merge_candidate/1" do
    setup do
      person = insert(:mpi, :person)
      master_person = insert(:mpi, :person)
      merge_candidate = insert(:mpi, :merge_candidate, person: person, master_person: master_person)

      %{merge_candidate: merge_candidate}
    end

    test "success", %{merge_candidate: merge_candidate} do
      manual_merge_candidate = insert(:deduplication, :manual_merge_candidate, merge_candidate_id: merge_candidate.id)

      manual_merge_candidate_id = manual_merge_candidate.id
      actor_id = UUID.generate()

      assert {:ok,
              %{
                assignee_id: ^actor_id,
                manual_merge_candidate: %{
                  id: ^manual_merge_candidate_id,
                  assignee_id: ^actor_id
                }
              }} = Rpc.assign_manual_merge_candidate(actor_id)
    end
  end

  describe "process_manual_merge_request/4" do
    setup do
      person = insert(:mpi, :person)
      master_person = insert(:mpi, :person)
      merge_candidate = insert(:mpi, :merge_candidate, person: person, master_person: master_person)

      manual_merge_candidate =
        insert(:deduplication, :manual_merge_candidate,
          person_id: merge_candidate.person_id,
          master_person_id: merge_candidate.master_person_id,
          merge_candidate_id: merge_candidate.id
        )

      %{merge_candidate: merge_candidate, manual_merge_candidate: manual_merge_candidate}
    end

    test "successful merge request", context do
      %{merge_candidate: merge_candidate, manual_merge_candidate: manual_merge_candidate} = context

      expect(CandidatesMergerKafkaMock, :publish_person_deactivation_event, fn candidate, _, "MANUAL_MERGE" ->
        assert %{master_person_id: merge_candidate.master_person_id, merge_person_id: merge_candidate.person_id} ==
                 candidate

        :ok
      end)

      merge_request = insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_merge_candidate)

      insert_list(2, :deduplication, :manual_merge_request,
        status: @status_merge,
        manual_merge_candidate: manual_merge_candidate
      )

      assert {:ok, %{status: @status_merge}} =
               Rpc.process_manual_merge_request(merge_request.id, @status_merge, merge_request.assignee_id)

      manual_merge_candidate = DeduplicationRepo.get(ManualMergeCandidate, manual_merge_candidate.id)
      assert ManualMergeCandidate.status(:processed) == manual_merge_candidate.status
    end

    test "successful split request", %{manual_merge_candidate: manual_merge_candidate} do
      merge_request = insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_merge_candidate)

      assert {:ok, %{status: @status_split}} =
               Rpc.process_manual_merge_request(merge_request.id, @status_split, merge_request.assignee_id)
    end

    test "request successfully postponed", %{manual_merge_candidate: manual_merge_candidate} do
      merge_request = insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_merge_candidate)

      assert {:ok, %{status: @status_postpone}} =
               Rpc.process_manual_merge_request(merge_request.id, @status_postpone, merge_request.assignee_id)
    end

    test "invalid comment type" do
      %{id: id, assignee_id: assignee_id} = insert(:deduplication, :manual_merge_request)

      assert {:error, %Changeset{valid?: false}} =
               Rpc.process_manual_merge_request(id, @status_merge, assignee_id, %{invalid: :type})
    end
  end

  describe "can_assign_new_manual_merge_request/1" do
    setup %{max_postponed_requests: max_postponed_requests} do
      prev_config = Application.get_env(:core, Core.ManualMerge)

      Application.put_env(
        :core,
        Core.ManualMerge,
        Keyword.replace!(prev_config, :max_postponed_requests, max_postponed_requests)
      )

      on_exit(fn -> Application.put_env(:core, Core.ManualMerge, prev_config) end)

      :ok
    end

    @tag max_postponed_requests: 1
    test "suceess with no merge_requests" do
      assignee_id = UUID.generate()

      assert {:ok, true} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end

    @tag max_postponed_requests: 3
    test "suceess with few merge_requests, filter by assignee_id" do
      assignee_id = UUID.generate()
      insert_list(2, :deduplication, :manual_merge_request, assignee_id: assignee_id, status: @status_postpone)
      insert_list(4, :deduplication, :manual_merge_request, status: @status_postpone)

      assert {:ok, true} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end

    @tag max_postponed_requests: 0
    test "fail with zero limit" do
      assignee_id = UUID.generate()

      assert {:ok, false} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end

    @tag max_postponed_requests: 5
    test "fail when already has new merge_request" do
      assignee_id = UUID.generate()
      insert(:deduplication, :manual_merge_request, assignee_id: assignee_id, status: @status_new)

      assert {:ok, false} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end

    @tag max_postponed_requests: 5
    test "fail to assign new merge_request due to limit" do
      assignee_id = UUID.generate()
      insert_list(5, :deduplication, :manual_merge_request, assignee_id: assignee_id, status: @status_postpone)

      assert {:ok, false} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end
  end
end
