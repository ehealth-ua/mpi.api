defmodule PersonDeactivatorTest do
  use Core.ModelCase, async: false
  doctest PersonDeactivator

  import Core.Factory
  import Ecto.Query
  import Mox

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.Repo
  alias Ecto.UUID

  setup :verify_on_exit!
  setup :set_mox_global

  describe "deactivate_persons/0" do
    test "deactivate_persons success" do
      Enum.each(1..3, fn _ -> insert(:mpi, :merge_candidate, score: 0.0) end)
      Enum.each(1..5, fn _ -> insert(:mpi, :merge_candidate, score: 0.6) end)
      Enum.each(1..2, fn _ -> insert(:mpi, :merge_candidate, score: 0.8) end)

      expect(PersonDeactivatorKafkaMock, :publish_person_merged_event, 2, fn _, _ -> :ok end)
      assert 2 == PersonDeactivator.deactivate_persons()
      assert 0 == PersonDeactivator.deactivate_persons()
    end
  end

  describe "deactivate candidates" do
    test "get_new_merge_candidates/2 new merge candidates" do
      mc =
        Enum.map(1..3, fn _ ->
          score = 1.0
          m = insert(:mpi, :merge_candidate, score: score)
          %{person_id: m.person_id, id: m.id}
        end)

      Enum.each(1..3, fn _ -> insert(:mpi, :merge_candidate, score: 0.0) end)

      dm = PersonDeactivator.get_new_merge_candidates(1, 100)
      assert MapSet.new(mc) == MapSet.new(dm)
    end

    test "get_new_merge_candidates/2 no merge candidates" do
      Enum.each(1..3, fn _ -> insert(:mpi, :merge_candidate, score: 0.0) end)

      Enum.each(1..3, fn _ ->
        insert(:mpi, :merge_candidate, score: 1.0, status: MergeCandidate.status(:merged))
      end)

      assert [] == PersonDeactivator.get_new_merge_candidates(0.6, 100)
    end

    test "deactivate_candidates" do
      system_user_id = UUID.generate()

      mc =
        Enum.map(1..3, fn _ ->
          score = 1.0
          m = insert(:mpi, :merge_candidate, score: score)
          m.id
        end)

      Enum.each(1..3, fn _ -> insert(:mpi, :merge_candidate, score: 0.0) end)

      merge_candidates = PersonDeactivator.get_new_merge_candidates(1, 100)

      PersonDeactivator.deactivate_candidates(merge_candidates, system_user_id)

      merged_candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> where([m], m.status == ^MergeCandidate.status(:merged))
        |> Repo.all()

      assert MapSet.new(mc) == merged_candidates |> Enum.map(& &1.id) |> MapSet.new()

      Enum.each(merged_candidates, fn %MergeCandidate{person: %Person{status: status}} ->
        assert status == Person.status(:inactive)
      end)
    end
  end
end
