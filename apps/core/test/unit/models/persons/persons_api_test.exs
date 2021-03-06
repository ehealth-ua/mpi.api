defmodule Core.Persons.PersonTest do
  use Core.ModelCase, async: false

  import Core.Factory
  alias Core.Person
  alias Core.Persons.PersonsAPI
  alias Core.PersonDocument
  alias Core.PersonUpdate
  alias Core.Repo

  @test_person_id "ce377777-d8c4-4dd8-9328-de24b1ee3879"
  @test_person_id2 "ce377777-d8c4-4dd8-9328-de24b1ee3880"
  @test_consumer_id "ce377888-d8c4-4dd8-9328-de24b1ee3881"
  @test_document_number "document-number-99999"
  @test_phone_number "phone-number-1"
  @test_phone_number2 "phone-number-2"

  @test_consumer_first_name_original "Bob"
  @test_consumer_first_name_changed "Robbie"

  @active Person.status(:active)
  @inactive Person.status(:inactive)

  test "inserts person in DB successfully" do
    %Ecto.Changeset{valid?: true} = changeset = PersonsAPI.changeset(%Person{}, build_person_map())

    assert {:ok, _record} = Repo.insert(changeset)
  end

  test "creates person" do
    active = Person.status(:active)
    assert {:created, {:ok, %Person{id: id}}} = PersonsAPI.create(build_person_map(), @test_consumer_id)

    assert [
             %PersonUpdate{
               person_id: ^id,
               updated_by: @test_consumer_id,
               inserted_by: @test_consumer_id,
               status: ^active
             }
           ] = Repo.all(PersonUpdate)
  end

  test "updates person" do
    insert_person_test_data(%{updated_by: @test_consumer_id, inserted_by: @test_consumer_id})

    person_map =
      build_person_map()
      |> Map.merge(%{
        "id" => @test_person_id,
        "first_name" => @test_consumer_first_name_changed,
        "status" => @inactive
      })

    assert {:ok, {:ok, %Person{id: id, inserted_by: inserted_by, first_name: @test_consumer_first_name_changed}}} =
             PersonsAPI.create(person_map, @test_consumer_id)

    assert [
             %PersonUpdate{
               person_id: ^id,
               updated_by: @test_consumer_id,
               inserted_by: @test_consumer_id,
               status: @active
             },
             %PersonUpdate{person_id: ^id, updated_by: @test_consumer_id, inserted_by: inserted_by, status: @inactive}
           ] = Repo.all(PersonUpdate)
  end

  test "show errors on update inactive person" do
    insert_person_test_data(%{id: @test_person_id, is_active: false})
    insert_person_test_data(%{id: @test_person_id2, status: Person.status(:inactive)})

    inactive_persons = [
      build_person_map() |> Map.merge(%{"id" => @test_person_id}),
      build_person_map() |> Map.merge(%{"id" => @test_person_id2})
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
                 documents: [
                   %PersonDocument{type: "BIRTH_CERTIFICATE", number: @test_document_number}
                 ]
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
                 documents: [%PersonDocument{type: "BIRTH_CERTIFICATE", number: "1test\\1"}]
               }
             ]
           } = PersonsAPI.search(%{"birth_certificate" => "1test\\1"})
  end

  test "searches with birth certificate invalid search symbols" do
    assert %Scrivener.Page{
             entries: [],
             page_number: 1,
             page_size: 2,
             total_entries: 0,
             total_pages: 1
           } == PersonsAPI.search(%{"birth_certificate" => "АК \"27", "page_size" => 2})
  end

  test "searches with auth phone number" do
    insert_person_test_data(%{
      id: @test_person_id,
      authentication_methods: [%{type: "OTP", phone_number: @test_phone_number}],
      person_authentication_methods: [%{type: "OTP", phone_number: @test_phone_number}]
    })

    insert_person_test_data(%{
      id: @test_consumer_id,
      authentication_methods: [%{type: "OTP", phone_number: @test_phone_number}],
      person_authentication_methods: [%{type: "OTP", phone_number: @test_phone_number}],
      status: Person.status(:inactive)
    })

    insert_person_test_data(%{
      id: @test_person_id2,
      authentication_methods: [
        %{type: "OTP", phone_number: @test_phone_number2},
        %{type: "OFFLINE"}
      ],
      person_authentication_methods: [
        %{type: "OTP", phone_number: @test_phone_number2},
        %{type: "OFFLINE"}
      ]
    })

    assert %Scrivener.Page{
             entries: [
               %Person{
                 id: @test_person_id,
                 authentication_methods: [
                   %{"type" => "OTP", "phone_number" => @test_phone_number}
                 ]
               }
             ]
           } = PersonsAPI.search(%{"auth_phone_number" => @test_phone_number})

    test_params_to_entries_count = [
      {%{"auth_phone_number" => @test_phone_number2}, 1},
      {%{}, 3}
    ]

    for {params, expected_count} <- test_params_to_entries_count do
      %Scrivener.Page{total_entries: ^expected_count} = PersonsAPI.search(params)
    end
  end

  test "searches by unzr, with tax_id and birthday presence" do
    %Person{id: id} =
      insert(
        :mpi,
        :person,
        tax_id: "0123456789",
        birth_date: ~D[1996-12-12],
        unzr: "19961212-01234"
      )

    Enum.each(1..100, fn n ->
      insert(
        :mpi,
        :person,
        tax_id: "0123456789",
        birth_date: ~D[1996-12-12],
        unzr: nil,
        last_name: Integer.to_string(n, 2)
      )
    end)

    assert %Scrivener.Page{
             entries: [%Person{id: s_id}]
           } =
             PersonsAPI.search(%{
               "unzr" => "19961212-01234",
               "tax_id" => "0123456789",
               birth_date: ~D[1996-12-12]
             })

    assert id == s_id
  end

  def insert_person_test_data(args \\ %{}) do
    def_args = %{id: @test_person_id, first_name: @test_consumer_first_name_original}
    person = insert(:mpi, :person, Map.merge(def_args, args))

    person
    |> Repo.preload(:phones)
    |> Repo.preload(:documents)
  end

  defp build_person_map, do: string_params_for(:person)
end
