defmodule MPI.RpcTest do
  @moduledoc false

  use Core.ModelCase, async: true

  import Core.Factory
  import Mox

  alias Core.Person
  alias Ecto.UUID
  alias MPI.Rpc
  alias Scrivener.Page

  setup :verify_on_exit!

  describe "search_persons_paginated/1" do
    test "search person by documents list and status" do
      %{id: person1_id} =
        insert(
          :mpi,
          :person,
          documents: [
            build(:document, type: "BIRTH_CERTIFICATE", number: "АА111"),
            build(:document, type: "PASSPORT", number: "аа222")
          ]
        )

      %{id: person2_id} =
        insert(
          :mpi,
          :person,
          documents: [
            build(:document, type: "BIRTH_CERTIFICATE", number: "АА333"),
            build(:document, type: "PASSPORT", number: "аа444")
          ]
        )

      %{id: person3_id} =
        insert(
          :mpi,
          :person,
          documents: [
            build(:document, type: "PASSPORT", number: "аа555")
          ]
        )

      insert(
        :mpi,
        :person,
        status: Person.status(:inactive),
        documents: [
          build(:document, type: "PASSPORT", number: "АА444")
        ]
      )

      insert(:mpi, :person)

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

      %Page{entries: persons} = Rpc.search_persons_paginated(search_params)
      {:ok, ^persons} = Rpc.search_persons(search_params)
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

      %Page{entries: persons} = Rpc.search_persons_paginated(search_params)
      {:ok, ^persons} = Rpc.search_persons(search_params)
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

      %Page{entries: persons} = Rpc.search_persons_paginated(search_params)
      {:ok, ^persons} = Rpc.search_persons(search_params)
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

      %Page{entries: persons} = Rpc.search_persons_paginated(search_params)
      {:ok, ^persons} = Rpc.search_persons(search_params)
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

      %Page{entries: persons} = Rpc.search_persons_paginated(search_params)
      {:ok, ^persons} = Rpc.search_persons(search_params)
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

      %Page{entries: persons} = Rpc.search_persons_paginated(search_params)
      {:ok, ^persons} = Rpc.search_persons(search_params)
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

      %Page{entries: persons} = Rpc.search_persons_paginated(search_params)
      {:ok, ^persons} = Rpc.search_persons(search_params)
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

      insert_list(4, :mpi, :person)
      insert_list(8, :mpi, :person, status: Person.status(:inactive))

      insert_list(
        2,
        :mpi,
        :person,
        no_tax_id: true,
        documents: [build(:document, type: "PASSPORT", number: document_number)],
        birth_date: birth_date,
        tax_id: tax_id,
        authentication_methods: build_list(1, :authentication_method, phone_number: phone_number)
      )

      person =
        insert(
          :mpi,
          :person,
          no_tax_id: false,
          documents: [build(:document, type: "PASSPORT", number: document_number)],
          birth_date: birth_date,
          tax_id: tax_id,
          authentication_methods: build_list(1, :authentication_method, phone_number: phone_number)
        )

      filter = [
        {:authentication_methods, :contains, [%{"phone_number" => phone_number}]},
        {:tax_id, :equal, tax_id},
        {:status, :equal, "ACTIVE"},
        {:birth_date, :equal, birth_date},
        {:documents, nil, [{:number, :equal, document_number}, {:type, :equal, "PASSPORT"}]}
      ]

      {:ok, persons} = Rpc.search_persons(filter, [asc: :no_tax_id], {0, 10})

      assert 3 == length(persons)
      assert person.id == hd(persons).id
    end

    test "success by persons id" do
      insert_list(4, :mpi, :person)

      persons = insert_list(2, :mpi, :person)
      persons_ids = Enum.map(persons, & &1.id)
      filter = [{:id, :in, persons_ids}]
      {:ok, persons} = Rpc.search_persons(filter)

      assert 2 == length(persons)
    end
  end

  describe "search_persons/2 with fields" do
    test "search_persons/2 by ids without fields" do
      %{id: id} = insert(:mpi, :person)
      insert(:mpi, :person)
      params = %{"ids" => Enum.join([id], ",")}
      assert %Scrivener.Page{entries: [person]} = Rpc.search_persons_paginated(params)
      assert {:ok, [^person]} = Rpc.search_persons(params)

      assert %{documents: _, phones: _, addresses: _, merged_persons: _, master_person: _} =
               Map.take(person, ~w(documents phones addresses merged_persons master_person)a)
    end

    test "search_persons/2 by ids" do
      fields = ~w(id first_name last_name second_name birth_date)a
      %{id: id1} = insert(:mpi, :person)
      %{id: id2} = insert(:mpi, :person)
      insert(:mpi, :person)

      assert {:ok, [_, _]} = Rpc.search_persons(%{"ids" => Enum.join([id1, id2], ",")}, fields)
    end

    test "search_persons/2 with fields by ids not found" do
      fields = ~w(id first_name last_name second_name birth_date)a
      insert(:mpi, :person)

      {:ok, []} = Rpc.search_persons(%{"ids" => Enum.join([UUID.generate()], ",")}, fields)
    end

    test "search_persons/2 with empty search params" do
      fields = ~w(id first_name last_name second_name birth_date)a
      insert(:mpi, :person)

      {:error, "search params is not specified"} = Rpc.search_persons(%{}, fields)
    end

    test "search_persons_paginated/2  with not-existing field return error" do
      %{id: id} = insert(:mpi, :person)

      assert {:error, "invalid search characters"} ==
               Rpc.search_persons_paginated(%{"id" => id}, [:id, :not_existing_field])
    end
  end

  describe "get_person_by_id/1" do
    test "success" do
      %{id: id} = insert(:mpi, :person)

      assert {:ok, %{id: ^id}} = Rpc.get_person_by_id(id)
    end

    test "not found" do
      refute Rpc.get_person_by_id(UUID.generate())
    end
  end

  describe "reset_auth_method/2" do
    test "success" do
      %{id: id} = insert(:mpi, :person, authentication_methods: [%{"type" => "PHONE"}])

      person = Rpc.reset_auth_method(id, UUID.generate())

      assert {:ok, %{id: ^id, authentication_methods: [%{"type" => "NA"}]}} = person
    end

    test "person inactive" do
      %{id: id} =
        insert(:mpi, :person, status: Person.status(:inactive), authentication_methods: [%{"type" => "PHONE"}])

      assert {:error, {:conflict, "Invalid status MPI for this action"}} = Rpc.reset_auth_method(id, UUID.generate())
    end

    test "not found" do
      refute Rpc.reset_auth_method(UUID.generate(), UUID.generate())
    end
  end

  describe "get_auth_method/1" do
    test "success" do
      %{id: id1} =
        insert(:mpi, :person,
          authentication_methods: [
            %{
              type: "OTP",
              phone_number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}"
            }
          ]
        )

      %{id: id2} =
        insert(:mpi, :person,
          authentication_methods: [
            %{
              type: "OFFLINE"
            }
          ]
        )

      assert {:ok, %{"phone_number" => _, "type" => "OTP"}} = Rpc.get_auth_method(id1)
      assert {:ok, %{"type" => "OFFLINE"}} = Rpc.get_auth_method(id2)
    end

    test "person not found" do
      refute Rpc.get_auth_method(UUID.generate())
    end
  end
end
