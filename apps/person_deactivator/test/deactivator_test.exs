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

  @active "active"
  setup :verify_on_exit!

  test "decline person if master exists" do
    mc = insert(:mpi, :merge_candidate, person: build(:person, master_person: build(:merged_pairs)))
    actor_id = UUID.generate()
    PersonDeactivator.deactivate_person(mc.master_person_id, mc.person_id, actor_id, "AUTO_MERGE")
    declined = MergeCandidate.status(:declined)
    assert %MergeCandidate{status: ^declined} = Repo.one(MergeCandidate)
  end

  test "deactivate_person mark merge candidate declined if master has no declaration" do
    expect(PersonDeactivatorKafkaMock, :publish_declaration_deactivation_event, 1, fn _, _, reason ->
      assert "AUTO_MERGE" == reason
      :ok
    end)

    expect(PersonDeactivatorKafkaMock, :publish_to_event_manager, 1, fn event ->
      assert_event(event)
      :ok
    end)

    actor_id = UUID.generate()
    mc_success = insert(:mpi, :merge_candidate)
    mc_empty = insert(:mpi, :merge_candidate)
    candidates = [mc_empty, mc_success]

    expect(RPCWorkerMock, :run, 2, fn "ops", OPS.Rpc, :get_declaration, [[person_id: id, status: @active]] ->
      cond do
        id == mc_success.master_person_id ->
          {:ok, %{}}

        id == mc_empty.master_person_id ->
          nil
      end
    end)

    Enum.map(candidates, fn mc ->
      PersonDeactivator.deactivate_person(mc.master_person_id, mc.person_id, actor_id, "AUTO_MERGE")
    end)

    assert 1 = MergedPair |> Repo.all() |> Enum.count()
    declined = MergeCandidate.status(:declined)
    assert %MergeCandidate{status: ^declined} = Repo.get(MergeCandidate, mc_empty.id)
  end

  test "deactivate_person that already was pushed to kafka but not merged" do
    expect(PersonDeactivatorKafkaMock, :publish_to_event_manager, 1, fn event ->
      assert_event(event)
      :ok
    end)

    mc = insert(:mpi, :merge_candidate, status: MergeCandidate.status(:deactivate_ready))
    actor_id = UUID.generate()
    PersonDeactivator.deactivate_person(mc.master_person.id, mc.person.id, actor_id, "AUTO_MERGE")
    assert %MergeCandidate{} = Repo.get_by!(MergeCandidate, id: mc.id, status: MergeCandidate.status(:merged))
  end

  test "deactivate_person mark stale candidate and do not push them to kafka" do
    expect(PersonDeactivatorKafkaMock, :publish_declaration_deactivation_event, 3, fn _, _, reason ->
      assert "AUTO_MERGE" == reason
      :ok
    end)

    expect(PersonDeactivatorKafkaMock, :publish_to_event_manager, 3, fn event ->
      assert_event(event)
      :ok
    end)

    expect(RPCWorkerMock, :run, 3, fn "ops", OPS.Rpc, :get_declaration, [[person_id: _, status: @active]] ->
      {:ok, %{}}
    end)

    p_updated_at = DateTime.add(DateTime.utc_now(), 1000)
    stale = MergeCandidate.status(:stale)
    mc_actual_candidates = insert_list(3, :mpi, :merge_candidate)
    mc_stale_candidate = insert(:mpi, :merge_candidate, person: build(:person, updated_at: p_updated_at))
    mc_stale_master = insert(:mpi, :merge_candidate, master_person: build(:person, updated_at: p_updated_at))
    actor_id = UUID.generate()
    candidates = [mc_stale_candidate, mc_stale_master | mc_actual_candidates]

    Enum.map(
      candidates,
      &PersonDeactivator.deactivate_person(&1.master_person_id, &1.person_id, actor_id, "AUTO_MERGE")
    )

    assert %MergeCandidate{status: ^stale} = Repo.get(MergeCandidate, mc_stale_candidate.id)
    assert %MergeCandidate{status: ^stale} = Repo.get(MergeCandidate, mc_stale_master.id)
    assert 3 = MergedPair |> Repo.all() |> Enum.count()
  end

  test "deactivate_person success" do
    expect(PersonDeactivatorKafkaMock, :publish_declaration_deactivation_event, 10, fn _, _, reason ->
      assert "AUTO_MERGE" == reason
      :ok
    end)

    expect(PersonDeactivatorKafkaMock, :publish_to_event_manager, 10, fn event ->
      assert_event(event)
      :ok
    end)

    expect(RPCWorkerMock, :run, 10, fn "ops", OPS.Rpc, :get_declaration, [[person_id: _, status: @active]] ->
      {:ok, %{}}
    end)

    actor_id = UUID.generate()
    candidates = prepare_candidates(10)

    Enum.map(
      candidates,
      &PersonDeactivator.deactivate_person(&1.master_person_id, &1.merge_person_id, actor_id, "AUTO_MERGE")
    )

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

  defp prepare_candidates(amount) do
    amount
    |> insert_list(:mpi, :merge_candidate, score: 0.9)
    |> Enum.map(fn candidate ->
      %{id: candidate.id, master_person_id: candidate.master_person_id, merge_person_id: candidate.person_id}
    end)
  end

  defp assert_event(event) do
    %{
      changed_by: _,
      entity_id: _,
      entity_type: "MergeCandidate",
      event_time: _,
      event_type: "StatusChangeEvent",
      properties: %{"status" => %{"new_value" => "inactive"}}
    } = event
  end
end
