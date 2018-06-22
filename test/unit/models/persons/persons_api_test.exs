defmodule MPI.Persons.PersonTest do
  use MPI.ModelCase, async: true

  import MPI.Factory

  alias MPI.{Person, Persons.PersonsAPI}

  @test_person_id "ce377777-d8c4-4dd8-9328-de24b1ee3879"
  @test_person_id2 "ce377777-d8c4-4dd8-9328-de24b1ee3880"
  @test_consumer_id "ce377888-d8c4-4dd8-9328-de24b1ee3881"
  @test_document_number "document-number-99999"

  @test_consumer_first_name_original "Bob"
  @test_consumer_first_name_changed "Robbie"

  test "inserts person in DB successfully" do
    %Ecto.Changeset{valid?: true} = changeset = PersonsAPI.changeset(%Person{}, build_person_map())
    assert {:ok, _record} = Repo.insert(changeset)
  end

  test "creates person" do
    assert {:created, {:ok, %Person{id: _}}} = PersonsAPI.create(build_person_map(), @test_consumer_id)
  end

  test "updates person" do
    insert_person_test_data()

    person_map =
      build_person_as_keyed_map()
      |> Map.merge(%{"id" => @test_person_id, "first_name" => @test_consumer_first_name_changed})

    assert {:ok, {:ok, %Person{first_name: @test_consumer_first_name_changed}}} =
             PersonsAPI.create(person_map, @test_consumer_id)
  end

  test "show errors on update inactive person" do
    insert_person_test_data(%{id: @test_person_id, is_active: false})
    insert_person_test_data(%{id: @test_person_id2, status: Person.status(:inactive)})

    inactive_persons = [
      build_person_as_keyed_map() |> Map.merge(%{"id" => @test_person_id}),
      build_person_as_keyed_map() |> Map.merge(%{"id" => @test_person_id2})
    ]

    for person_data <- inactive_persons do
      assert {:error, {:conflict, "person is not active"}} = PersonsAPI.create(person_data, @test_consumer_id)
    end
  end

  test "searches with birth certificate" do
    insert_person_test_data(%{
      id: @test_person_id,
      documents: [%{type: "BIRTH_CERTIFICATE", number: @test_document_number}]
    })

    insert_person_test_data(%{id: @test_person_id2})

    assert %Scrivener.Page{
             entries: [
               %Person{
                 id: @test_person_id,
                 documents: [%{"type" => "BIRTH_CERTIFICATE", "number" => @test_document_number}]
               }
             ]
           } = PersonsAPI.search(%{"birth_certificate" => @test_document_number})

    expected_entries_count = 2
    assert expected_entries_count === PersonsAPI.search(%{"birth_certificate" => nil}).total_entries
  end

  test "searches with birth certificate escape" do
    insert_person_test_data(%{
      id: @test_person_id,
      documents: [%{type: "BIRTH_CERTIFICATE", number: "1test\\1"}]
    })

    assert %Scrivener.Page{
             entries: [
               %Person{
                 documents: [%{"type" => "BIRTH_CERTIFICATE", "number" => "1test\\1"}]
               }
             ]
           } = PersonsAPI.search(%{"birth_certificate" => "1test\\1"})

    %Scrivener.Page{
      entries: [
        %Person{
          id: @test_person_id,
          documents: [%{type: "BIRTH_CERTIFICATE", number: "1test\\1"}]
        }
      ]
    }
  end

  test "searches with birth certificate invalid search symbols" do
    assert %Scrivener.Page{
             entries: [],
             page_number: 1,
             page_size: 2,
             total_entries: 0,
             total_pages: 1
           } == PersonsAPI.search(%{"birth_certificate" => "АК \"27"})
  end

  test "searches with type and nubmer" do
    insert_person_test_data(%{
      id: @test_person_id,
      documents: [%{type: "PASSPORT", number: @test_document_number}]
    })

    insert_person_test_data(%{id: @test_person_id2, documents: []})

    assert %Scrivener.Page{
             entries: [
               %Person{id: @test_person_id, documents: [%{"type" => "PASSPORT", "number" => @test_document_number}]}
             ]
           } = PersonsAPI.search(%{"type" => "passport", "number" => @test_document_number})

    test_params_to_entries_count = [
      {%{"type" => "PASSPORT", "number" => @test_document_number}, 1},
      {%{"type" => "passport", "number" => @test_document_number}, 1},
      {%{"type" => "national_id", "number" => @test_document_number}, 0},
      {%{"type" => nil}, 2},
      {%{}, 2}
    ]

    for {params, expected_count} <- test_params_to_entries_count do
      assert PersonsAPI.search(params).total_entries === expected_count
    end
  end

  def insert_person_test_data(args \\ %{}) do
    def_args = %{id: @test_person_id, first_name: @test_consumer_first_name_original}
    person = insert(:person, Map.merge(def_args, args))

    if_nil = fn
      nil -> []
      attrs when is_list(attrs) -> attrs
      _ -> {:error, :attribute_type}
    end

    Enum.each(if_nil.(person.documents), fn document ->
      insert(:person_document, [{:person_id, person.id} | Map.to_list(document)])
    end)

    Enum.each(if_nil.(person.phones), fn phone ->
      insert(:person_phone, [{:person_id, person.id} | Map.to_list(phone)])
    end)

    person
    |> Repo.preload(:person_phones)
    |> Repo.preload(:person_documents)
  end

  defp build_person_map do
    :person |> build() |> Map.from_struct()
  end

  defp build_person_as_keyed_map do
    for {key, val} <- build_person_map(), into: %{}, do: {Atom.to_string(key), val}
  end
end
