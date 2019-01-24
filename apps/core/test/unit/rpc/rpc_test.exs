defmodule Core.RpcTest do
  @moduledoc false

  use Core.ModelCase, async: true

  import Core.Factory

  alias Core.Person
  alias Core.Rpc
  alias Scrivener.Page
  alias Ecto.UUID

  describe "search_persons/1" do
    test "search person by documents list and status" do
      %{id: person1_id} = insert(
        :person,
        documents: [
          build(:document, type: "BIRTH_CERTIFICATE", number: "АА111"),
          build(:document, type: "PASSPORT", number: "аа222")
        ]
      )

      %{id: person2_id} = insert(
        :person,
        documents: [
          build(:document, type: "BIRTH_CERTIFICATE", number: "АА333"),
          build(:document, type: "PASSPORT", number: "аа444")
        ]
      )

      %{id: person3_id} = insert(
        :person,
        documents: [
          build(:document, type: "PASSPORT", number: "аа555")
        ]
      )

      insert(
        :person,
        status: Person.status(:inactive),
        documents: [
          build(:document, type: "PASSPORT", number: "АА444")
        ]
      )

      insert(:person)

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "аа444"
          },
          %{
            "type" => "PASSPORT",
            "number" => "аа555"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 2 == length(person_ids)

      assert Enum.sort([person2_id, person3_id]) == Enum.sort(person_ids)

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "АА222"
          },
          %{
            "type" => "BIRTH_CERTIFICATE",
            "number" => "АА333"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 2 == length(person_ids)

      assert Enum.sort([person1_id, person2_id]) == Enum.sort(person_ids)

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "АА222"
          },
          %{
            "type" => "BIRTH_CERTIFICATE",
            "number" => "аа111"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 1 == length(person_ids)

      assert [person1_id] == person_ids

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "аа222"
          },
          %{
            "type" => "PASSPORT",
            "number" => "АА222"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 1 == length(person_ids)

      assert [person1_id] == person_ids

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "аа222"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 1 == length(person_ids)

      assert [person1_id] == person_ids

      search_params = %{
        "documents" => [
          %{
            "type" => "BIRTH_CERTIFICATE",
            "digits" => "333"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 1 == length(person_ids)

      assert [person2_id] == person_ids

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "АА777"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 0 == length(person_ids)
    end
  end

  describe "search_persons/3" do
    test "success" do
      tax_id = "0123456789"
      birth_date = ~D[1990-10-10]
      phone_number = "+3809900011122"
      document_number = "АА444009"

      insert_list(10, :person)

      insert_list(
        3,
        :person,
        status: Person.status(:active),
        documents: [build(:document, type: "PASSPORT", number: document_number)],
        birth_date: birth_date,
        tax_id: tax_id,
        authentication_methods: build_list(1, :authentication_method, phone_number: phone_number)
      )

      filter = [
        {:authentication_methods, :contains, [%{"phone_number" => phone_number}]},
        {:tax_id, :equal, tax_id},
        {:birth_date, :equal, birth_date},
        {:documents, nil, [{:number, :equal, document_number}, {:type, :equal, "PASSPORT"}]}
      ]

      {:ok, persons} = Rpc.search_persons(filter, [asc: :birth_date], {0, 10})

      assert 3 == length(persons)
    end

    test "success by persons id" do
      insert_list(4, :person)

      persons = insert_list(2, :person)
      persons_ids = Enum.map(persons, & &1.id)

      filter = [{:id, :in, persons_ids}]
      {:ok, persons} = Rpc.search_persons(filter)

      assert 2 == length(persons)
    end
  end

  describe "get_person_by_id/1" do
    test "success" do
      %{id: id} = insert(:person)

      assert {:ok, %Person{id: ^id}} = Rpc.get_person_by_id(id)
    end

    test "not found" do
      refute Rpc.get_person_by_id(UUID.generate())
    end
  end

  describe "reset_auth_method/2" do
    test "success" do
      %{id: id} = insert(:person, authentication_methods: [%{"type" => "PHONE"}])

      person = Rpc.reset_auth_method(id, UUID.generate())

      assert {:ok, %Person{id: ^id, authentication_methods: [%{"type" => "NA"}]}} = person
    end

    test "person inactive" do
      %{id: id} = insert(:person, status: Person.status(:inactive), authentication_methods: [%{"type" => "PHONE"}])

      assert {:error, {:conflict, "Invalid status MPI for this action"}} = Rpc.reset_auth_method(id, UUID.generate())
    end

    test "not found" do
      refute Rpc.reset_auth_method(UUID.generate(), UUID.generate())
    end
  end
end
