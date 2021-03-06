defmodule MPI.RpcTest do
  @moduledoc false

  use Core.ModelCase, async: true

  import Core.Factory
  import Mox

  alias Core.Person
  alias Ecto.UUID
  alias MPI.Rpc

  @status_active Person.status(:active)
  @status_inactive Person.status(:inactive)

  setup :verify_on_exit!

  describe "search_persons/1" do
    test "invalid arguments" do
      assert {:error, "search params are not specified"} == Rpc.search_persons(%{})
      assert {:error, "search params are not specified"} == Rpc.search_persons(%{"page_size" => 1})
      assert {:error, "search params are not specified"} == Rpc.search_persons(%{unzr: "19910824-00000"})

      assert {:error, "listed fields could not be fetched"} ==
               Rpc.search_persons(%{"unzr" => "19910824-00000"}, [:no_such_field])
    end

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

      {:ok, persons} = Rpc.search_persons(search_params)
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

      {:ok, persons} = Rpc.search_persons(search_params)
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

      {:ok, persons} = Rpc.search_persons(search_params)
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

      {:ok, persons} = Rpc.search_persons(search_params)
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

      {:ok, persons} = Rpc.search_persons(search_params)
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

      {:ok, persons} = Rpc.search_persons(search_params)
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

      {:ok, persons} = Rpc.search_persons(search_params)
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

      authentication_methods = build_list(1, :authentication_method, phone_number: phone_number)

      insert_list(
        2,
        :mpi,
        :person,
        no_tax_id: true,
        documents: [build(:document, type: "PASSPORT", number: document_number)],
        birth_date: birth_date,
        tax_id: tax_id,
        person_authentication_methods: authentication_methods,
        authentication_methods: array_of_map(authentication_methods)
      )

      authentication_methods = build_list(1, :authentication_method, phone_number: phone_number)

      person =
        insert(
          :mpi,
          :person,
          no_tax_id: false,
          documents: [build(:document, type: "PASSPORT", number: document_number)],
          birth_date: birth_date,
          tax_id: tax_id,
          person_authentication_methods: authentication_methods,
          authentication_methods: array_of_map(authentication_methods)
        )

      filter = [
        {:authentication_methods, :contains, [%{"phone_number" => phone_number}]},
        {:tax_id, :equal, tax_id},
        {:status, :equal, "ACTIVE"},
        {:birth_date, :equal, birth_date},
        {:documents, nil, [{:number, :equal, document_number}, {:type, :equal, "PASSPORT"}]}
      ]

      {:ok, persons} = Rpc.ql_search(filter, [asc: :no_tax_id], {0, 10})

      assert 3 == length(persons)
      assert person.id == hd(persons).id
    end

    test "success by persons id" do
      insert_list(4, :mpi, :person)

      persons = insert_list(2, :mpi, :person)
      persons_ids = Enum.map(persons, & &1.id)
      filter = [{:id, :in, persons_ids}]
      {:ok, persons} = Rpc.ql_search(filter)

      assert 2 == length(persons)
    end
  end

  describe "search_persons/2 with fields" do
    test "search_persons/2 by ids without fields" do
      %{id: id} = insert(:mpi, :person)
      insert(:mpi, :person)
      params = %{"ids" => Enum.join([id], ",")}
      assert {:ok, [person]} = Rpc.search_persons(params)

      assert %{documents: _, phones: _, addresses: _, merged_persons: _, master_person: _} =
               Map.take(person, ~w(documents phones addresses merged_persons master_person)a)
    end

    test "search_persons/2 by ids with all params" do
      %{id: id} = insert(:mpi, :person)
      insert(:mpi, :person)
      params = %{"ids" => id}

      assert {:ok, %{data: [%{id: ^id}], paging: %{total_entries: 1}}} =
               Rpc.search_persons(params, [:id], paginate: true)
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

      {:error, "search params are not specified"} = Rpc.search_persons(%{}, fields)
    end

    test "search_persons/2  with not-existing field return error" do
      %{id: id} = insert(:mpi, :person)

      assert {:error, "listed fields could not be fetched"} ==
               Rpc.search_persons(%{"id" => id}, [:id, :not_existing_field])
    end
  end

  describe "get_person_by_id/2" do
    test "success" do
      %{id: id} = insert(:mpi, :person)

      assert {:ok, %{id: ^id}} = Rpc.get_person_by_id(id)
    end

    test "success with fields param" do
      person = insert(:mpi, :person)
      person_id = person.id
      fields = ~w(id first_name last_name second_name birth_date)a

      resp = Rpc.get_person_by_id(person_id, fields)
      assert {:ok, %{id: ^person_id}} = resp
      assert resp |> elem(1) |> Map.keys() |> MapSet.new() == MapSet.new(fields)
    end

    test "not found" do
      refute Rpc.get_person_by_id(UUID.generate())
    end

    test "success when person_authentication_methods attr is empty" do
      person =
        insert(
          :mpi,
          :person,
          person_authentication_methods: []
        )

      person_id = person.id
      authentication_methods = person.authentication_methods
      rpc_response = Rpc.get_person_by_id(person.id)

      assert {:ok, %{id: ^person_id}} = rpc_response

      assert authentication_methods
             |> Enum.map(fn authentication_method ->
               Enum.into(authentication_method, %{}, fn {k, v} -> {String.to_atom(k), v} end)
             end) ==
               rpc_response
               |> elem(1)
               |> Map.get(:authentication_methods)
    end
  end

  describe "reset_auth_method/2" do
    test "success" do
      %{id: id} = insert(:mpi, :person, authentication_methods: [%{"type" => "PHONE"}])

      person = Rpc.reset_auth_method(id, UUID.generate())

      assert {:ok, %{id: ^id, authentication_methods: authentication_methods}} = person
      assert "NA" == hd(authentication_methods).type
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
      phone_number = "+38#{Enum.random(1_000_000_000..9_999_999_999)}"

      # persons with person_authentication_methods loaded

      %{id: id1} =
        insert(:mpi, :person,
          authentication_methods: [
            %{
              type: "OTP",
              phone_number: phone_number
            }
          ],
          person_authentication_methods: [
            %{
              type: "OTP",
              phone_number: phone_number
            }
          ]
        )

      %{id: id2} =
        insert(:mpi, :person,
          authentication_methods: [%{type: "OFFLINE"}],
          person_authentication_methods: [%{type: "OFFLINE"}]
        )

      # persons with empty person_authentication_methods

      %{id: id3} =
        insert(:mpi, :person,
          authentication_methods: [
            %{
              type: "OTP",
              phone_number: phone_number
            }
          ],
          person_authentication_methods: []
        )

      %{id: id4} =
        insert(:mpi, :person,
          authentication_methods: [%{type: "OFFLINE"}],
          person_authentication_methods: []
        )

      assert {:ok, %{"phone_number" => phone_number, "type" => "OTP"}} = Rpc.get_auth_method(id1)
      assert {:ok, %{"type" => "OFFLINE"}} = Rpc.get_auth_method(id2)
      assert {:ok, %{"phone_number" => phone_number, "type" => "OTP"}} = Rpc.get_auth_method(id3)
      assert {:ok, %{"type" => "OFFLINE"}} = Rpc.get_auth_method(id4)
    end

    test "person not found" do
      refute Rpc.get_auth_method(UUID.generate())
    end
  end

  describe "create_or_update_person/2" do
    test "success" do
      updated_by = UUID.generate()
      %{id: person_id} = insert(:mpi, :person, status: @status_active)

      assert {:ok, person} = Rpc.create_or_update_person(%{"id" => person_id, "status" => @status_inactive}, updated_by)

      assert @status_inactive == person.status
      assert updated_by == person.updated_by
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
