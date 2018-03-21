defmodule MPI.PersonTest do
  use MPI.ModelCase, async: true

  import MPI.Factory

  alias MPI.Person
  alias MPI.Persons.PersonsAPI

  @test_person_id "ce377777-d8c4-4dd8-9328-de24b1ee3879"
  @test_person_id2 "ce377777-d8c4-4dd8-9328-de24b1ee3880"
  @test_consumer_id "ce377888-d8c4-4dd8-9328-de24b1ee3881"

  @test_consumer_first_name_original "Bob"
  @test_consumer_first_name_changed "Robbie"

  test "Inserts person in DB successfully" do
    %Ecto.Changeset{valid?: true} = changeset = PersonsAPI.changeset(%Person{}, build_person_map())
    assert {:ok, _record} = Repo.insert(changeset)
  end

  test "Creates person" do
    assert {:created, {:ok, %Person{id: _}}} = PersonsAPI.create(build_person_map(), @test_consumer_id)
  end

  test "Updates person" do
    insert_person_test_data()

    person_map =
      build_person_as_keyed_map()
      |> Map.merge(%{"id" => @test_person_id, "first_name" => @test_consumer_first_name_changed})

    assert {:ok, {:ok, %Person{first_name: @test_consumer_first_name_changed}}} =
             PersonsAPI.create(person_map, @test_consumer_id)
  end

  test "Show errors on update inactive person" do
    insert_person_test_data(%{id: @test_person_id, is_active: false})
    insert_person_test_data(%{id: @test_person_id2, status: Person.status(:inactive)})

    inactive_persons = [
      build_person_as_keyed_map() |> Map.merge(%{"id" => @test_person_id}),
      build_person_as_keyed_map() |> Map.merge(%{"id" => @test_person_id2})
    ]

    Enum.map(inactive_persons, fn person_data ->
      assert {:error, {:conflict, "person is not active"}} = PersonsAPI.create(person_data, @test_consumer_id)
    end)
  end

  defp insert_person_test_data(merge_data \\ %{}) do
    insert(:person, Map.merge(%{id: @test_person_id, first_name: @test_consumer_first_name_original}, merge_data))
  end

  defp build_person_map do
    :person |> build() |> Map.from_struct()
  end

  defp build_person_as_keyed_map do
    for {key, val} <- build_person_map(), into: %{}, do: {Atom.to_string(key), val}
  end
end
