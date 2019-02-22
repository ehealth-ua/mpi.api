defmodule MPIScheduler.Jobs.ContractRequestsTerminatorTest do
  @moduledoc false
  use Core.ModelCase, async: false

  import Core.Factory

  alias Core.MergeCandidate
  alias MPIScheduler.Jobs.AutoMergePersonsDeactivator

  test "run/0" do
    insert_list(3, :mpi, :merge_candidate, score: 0.89999999)
    insert_list(2, :mpi, :merge_candidate, score: 0.90001)
    insert_list(5, :mpi, :merge_candidate, score: 0.92)

    expect(CandidatesMergerKafkaMock, :publish_person_deactivation_event, fn candidates, _system_user_id ->
      assert 7 == length(candidates)
      :ok
    end)

    AutoMergePersonsDeactivator.run()
  end

  test "get_new_merge_candidates/2 new merge candidates" do
    mc =
      Enum.map(1..3, fn _ ->
        score = 1.0
        m = insert(:mpi, :merge_candidate, score: score)
        %{person_id: m.person_id, id: m.id}
      end)

    insert_list(3, :mpi, :merge_candidate, score: 0.0)

    dm = AutoMergePersonsDeactivator.get_merge_candidates(1, 100)
    assert MapSet.new(mc) == MapSet.new(dm)
  end

  test "get_new_merge_candidates/2 no merge candidates" do
    insert_list(3, :mpi, :merge_candidate, score: 0.0)
    insert_list(3, :mpi, :merge_candidate, score: 1.0, status: MergeCandidate.status(:merged))

    assert [] == AutoMergePersonsDeactivator.get_merge_candidates(0.6, 100)
  end
end