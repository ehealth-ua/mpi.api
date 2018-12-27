defmodule Core.RpcTest do
  @moduledoc false

  use Core.ModelCase, async: true

  import Core.Factory

  alias Core.Person
  alias Core.Rpc
  alias Scrivener.Page
  alias Ecto.UUID

  describe "search_persons/2" do
    test "search person by documents list and status" do
      %{id: person1_id} = insert(:person, documents: [
        build(:document, type: "BIRTH_CERTIFICATE", number: "АА111"),
        build(:document, type: "PASSPORT", number: "аа222")
      ])

      %{id: person2_id} = insert(:person, documents: [
        build(:document, type: "BIRTH_CERTIFICATE", number: "АА333"),
        build(:document, type: "PASSPORT", number: "аа444")
      ])

      %{id: person3_id} = insert(:person, documents: [
        build(:document, type: "PASSPORT", number: "аа555")
      ])

      insert(:person, status: Person.status(:inactive), documents: [
        build(:document, type: "PASSPORT", number: "АА444")
      ])

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

  describe "get_person_by_id/1" do
    test "success" do
      %{id: id} = insert(:person)

      assert {:ok, %Person{id: ^id}} = Rpc.get_person_by_id(id)
    end

    test "not found" do
      refute Rpc.get_person_by_id(UUID.generate())
    end
  end
end
