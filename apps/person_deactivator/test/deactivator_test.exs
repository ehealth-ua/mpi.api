defmodule PersonDeactivatorTest do
  use Core.ModelCase, async: false
  doctest PersonDeactivator

  import Core.Factory
  import Ecto.Query
  import Mox

  alias Core.MergeCandidate
  alias Core.MergedPair
  alias Core.Person
  alias Core.Repo
  alias Ecto.UUID

  setup :verify_on_exit!

  describe "deactivate_person/2" do
    test "deactivate_person success" do
      expect(PersonDeactivatorKafkaMock, :publish_declaration_deactivation_event, 10, fn _, _, reason ->
        assert "AUTO_MERGE" == reason
        :ok
      end)

      actor_id = UUID.generate()
      candidates = prepare_candidates(10)
      Enum.map(candidates, &PersonDeactivator.deactivate_person(&1, actor_id, "AUTO_MERGE"))

      merged_candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> where([m], m.status == ^MergeCandidate.status(:merged))
        |> Repo.all()

      assert 10 = length(merged_candidates)

      Enum.each(merged_candidates, fn %MergeCandidate{person: %Person{status: status}} ->
        assert status == Person.status(:inactive)
      end)

      assert 10 = MergedPair |> Repo.all() |> Enum.count()
    end
  end

  defp prepare_candidates(amount) do
    amount
    |> insert_list(:mpi, :merge_candidate, score: 0.9)
    |> Enum.map(fn candidate ->
      %{id: candidate.id, master_person_id: candidate.master_person_id, merge_person_id: candidate.person_id}
    end)
  end
end
