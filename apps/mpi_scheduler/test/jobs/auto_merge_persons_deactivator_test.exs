defmodule MPIScheduler.Jobs.AutoMergePersonsDeactivatorTest do
  @moduledoc false
  use Core.ModelCase, async: false

  import Core.Factory

  alias Core.MergeCandidate
  alias Core.Repo
  alias MPIScheduler.Jobs.AutoMergePersonsDeactivator

  test "run/0" do
    insert_list(3, :mpi, :merge_candidate, score: 0.89999999)
    insert_list(2, :mpi, :merge_candidate, score: 0.90001)
    insert_list(5, :mpi, :merge_candidate, score: 0.92)

    expect(CandidatesMergerKafkaMock, :publish_person_deactivation_event, 7, fn _candidate, _system_user_id, reason ->
      assert "AUTO_MERGE" == reason
      :ok
    end)

    AutoMergePersonsDeactivator.run()
  end

  test "get_new_merge_candidates/2 new merge candidates" do
    in_process = MergeCandidate.status(:in_process)

    mc =
      Enum.map(1..3, fn _ ->
        score = 1.0
        insert(:mpi, :merge_candidate, score: score)
      end)

    insert_list(3, :mpi, :merge_candidate, score: 0.0)
    insert_list(3, :mpi, :merge_candidate, status: in_process)

    dm = AutoMergePersonsDeactivator.get_merge_candidates(1, 100)
    mc_ids = Enum.map(mc, & &1.id)
    dm_ids = Enum.map(dm, & &1.id)

    MergeCandidate
    |> Repo.all()
    |> Enum.filter(&(&1.id in mc_ids))
    |> Enum.all?(&(in_process == &1.status))

    assert MapSet.new(dm_ids) == MapSet.new(mc_ids)
  end

  test "get_new_merge_candidates/2 no merge candidates" do
    insert_list(3, :mpi, :merge_candidate, score: 0.0)
    insert_list(3, :mpi, :merge_candidate, score: 1.0, status: MergeCandidate.status(:merged))

    assert [] == AutoMergePersonsDeactivator.get_merge_candidates(0.6, 100)
  end
end
