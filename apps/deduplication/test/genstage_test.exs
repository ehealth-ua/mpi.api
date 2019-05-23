defmodule Deduplication.GenStageTest do
  @moduledoc false

  use Core.ModelCase, async: false
  use Confex, otp_app: :deduplication
  import Ecto.Query
  import Core.Factory
  import Mox

  alias Core.MergeCandidate
  alias Core.Repo
  alias Core.VerifyingId
  alias Deduplication.Model
  alias Deduplication.DeduplicationPool

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    Model.set_current_verified_ts(DateTime.utc_now())
    :ok
  end

  def candidate_count(n), do: candidate_count(n, 0)
  def candidate_count(1, acc), do: acc
  def candidate_count(n, acc), do: candidate_count(n - 1, n - 1 + acc)

  def start_genstage(timeout) do
    Enum.map(
      [GenStageProducer | DeduplicationPool.consumer_ids()],
      &Supervisor.terminate_child(Deduplication.Supervisor.GenStage, &1)
    )

    Supervisor.start_link(DeduplicationPool.children(), strategy: :one_for_all)
    DeduplicationPool.subscribe()
    Process.sleep(timeout)
  end

  describe "test run gen stage" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      :ok
    end

    @tag :pending
    test "for completed db works" do
      Enum.map(1..300, fn _ -> insert(:mpi, :person) end)
      Model.set_current_verified_ts(DateTime.utc_now())
      start_genstage(100)
      assert 0 == Enum.count(Model.get_unverified_persons(300))
    end
  end

  describe "test run gen stage for random persons" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      :ok
    end

    @tag :pending
    test "for random persons works" do
      Enum.map(1..100, fn _ -> insert(:mpi, :person) end)
      start_genstage(5000)
      assert 0 == Enum.count(Model.get_unverified_persons(100))
    end
  end

  describe "test run gen stage for precounted persons" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      :ok
    end

    @tag :pending
    test "for existing unverified persons works" do
      Repo.delete_all(VerifyingId)
      n1 = 29
      n2 = 23

      Enum.each(1..n1, fn i ->
        authentication_methods = [build(:authentication_method, type: "OFFLINE")]

        insert(:mpi, :person,
          tax_id: "123456789",
          first_name: "#{i}",
          documents: [build(:document, number: "#{i}")],
          person_authentication_methods: authentication_methods,
          authentication_methods: array_of_map(authentication_methods)
        )
      end)

      Enum.each(1..n2, fn i ->
        authentication_methods = [build(:authentication_method, type: "OFFLINE")]

        insert(:mpi, :person,
          tax_id: "000000000",
          first_name: "#{i}",
          documents: [build(:document, number: "999#{i}")],
          person_authentication_methods: authentication_methods,
          authentication_methods: array_of_map(authentication_methods)
        )
      end)

      start_genstage(5000)

      merge_candidates_number =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()
        |> Enum.map(fn %MergeCandidate{master_person: mp, person: p} ->
          assert mp.tax_id == p.tax_id
        end)
        |> Enum.count()

      uniq_merge_candidates_number =
        MergeCandidate
        |> distinct(true)
        |> select([m], [m.master_person_id, m.person_id])
        |> Repo.all()
        |> Enum.count()

      assert candidate_count(n1) + candidate_count(n2) == merge_candidates_number
      assert candidate_count(n1) + candidate_count(n2) == uniq_merge_candidates_number
    end
  end

  describe "only with failed persons works" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      :ok
    end

    @tag :pending
    test "only failed persons" do
      Enum.map(1..110, fn _ ->
        person = insert(:mpi, :person)
        insert(:mpi, :verifying_ids, id: person.id)
      end)

      Model.set_current_verified_ts(DateTime.utc_now())
      assert 110 == Enum.count(Model.get_locked_unverified_persons())
      start_genstage(5000)
      assert 0 == Enum.count(Model.get_unverified_persons(110))
      assert 0 == Enum.count(Model.get_locked_unverified_persons())
    end
  end

  describe "both failed and unverified persons works" do
    test "unverified + failed persons" do
      Enum.map(1..51, fn _ ->
        person = insert(:mpi, :person)
        insert(:mpi, :verifying_ids, id: person.id)
      end)

      Model.set_current_verified_ts(DateTime.utc_now())
      insert_list(53, :mpi, :person)
      assert 51 == Enum.count(Model.get_locked_unverified_persons())
      start_genstage(5000)
      assert 0 == Enum.count(Model.get_unverified_persons(300))
      assert 0 == Enum.count(Model.get_locked_unverified_persons())
    end
  end

  defp array_of_map(authentication_methods) do
    Enum.map(authentication_methods, fn authentication_method ->
      authentication_method
      |> Map.take(~w(type phone_number)a)
      |> Enum.filter(fn {_, v} -> !is_nil(v) end)
      |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
    end)
  end
end
