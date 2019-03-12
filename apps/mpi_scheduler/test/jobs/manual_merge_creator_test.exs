defmodule MPIScheduler.Jobs.ManualMergeCandidatesCreatorTest do
  @moduledoc false
  use Core.ModelCase, async: false

  import Core.Factory
  import ExUnit.CaptureLog

  alias Core.ManualMerge.AuditLog
  alias Core.ManualMergeCandidate
  alias Core.DeduplicationRepo
  alias MPIScheduler.Jobs.ManualMergeCandidatesCreator

  test "run/0" do
    insert_list(10, :mpi, :merge_candidate, score: 0.89999999)
    insert_list(20, :mpi, :merge_candidate, score: 0.90001)
    insert_list(40, :mpi, :merge_candidate, score: 0.69999)
    insert_list(80, :mpi, :merge_candidate, score: 0.748)

    ManualMergeCandidatesCreator.run()

    manual_merge_candidates = DeduplicationRepo.all(ManualMergeCandidate)
    assert 90 = length(manual_merge_candidates)
    assert 90 == length(DeduplicationRepo.all(AuditLog))

    # duplicated manual merge candidates ignored
    ManualMergeCandidatesCreator.run()
    manual_merge_candidates = DeduplicationRepo.all(ManualMergeCandidate)
    assert 90 = length(manual_merge_candidates)
    assert 90 == length(DeduplicationRepo.all(AuditLog))

    # added new merge candidates for gray zone
    insert_list(30, :mpi, :merge_candidate, score: 0.856)

    ManualMergeCandidatesCreator.run()
    manual_merge_candidates = DeduplicationRepo.all(ManualMergeCandidate)
    assert 120 = length(manual_merge_candidates)
    assert 120 == length(DeduplicationRepo.all(AuditLog))
  end

  test "run/0 when max offset is reached" do
    insert_list(130, :mpi, :merge_candidate, score: 0.748)

    assert capture_log(fn ->
             ManualMergeCandidatesCreator.run()
           end) =~ "Maximum offset for MergeCandidates is reached"

    manual_merge_candidates = DeduplicationRepo.all(ManualMergeCandidate)
    assert 120 = length(manual_merge_candidates)
    assert 120 == length(DeduplicationRepo.all(AuditLog))
  end
end
