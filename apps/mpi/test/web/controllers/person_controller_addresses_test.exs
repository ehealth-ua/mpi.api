defmodule MPI.Web.PersonControllerAddressesTest do
  @moduledoc false

  use MPI.Web.ConnCase
  import Core.Factory
  alias Core.Person
  alias Core.PersonAddress
  alias Core.Persons.PersonsAPI

  def assert_person_addresses(person_addresses, data_addresses) do
    ps =
      person_addresses
      |> Enum.map(fn
        %PersonAddress{settlement: settlement} -> settlement
        %{settlement: settlement} -> settlement
      end)
      |> MapSet.new()

    ds = data_addresses |> Enum.map(&Map.get(&1, "settlement")) |> MapSet.new()
    assert ds == ps
  end

  describe "addresses and person_adresses" do
    test "get person with addresses", %{conn: conn} do
      person =
        insert(:mpi, :person,
          addresses: [build(:address, settlement: "Біла Церква")],
          person_addresses: [build(:address, settlement: "Чернігів")]
        )

      resp =
        conn
        |> get(person_path(conn, :show, person.id))
        |> json_response(200)

      assert resp["data"]["id"] == person.id
      assert_person_addresses(person.addresses, resp["data"]["addresses"])
      [%{"settlement" => "Біла Церква"}] = resp["data"]["addresses"]
    end

    test "get person without addresses", %{conn: conn} do
      person = insert(:mpi, :person, addresses: [], person_addresses: [])

      resp =
        conn
        |> get(person_path(conn, :show, person.id))
        |> json_response(200)

      assert resp["data"]["id"] == person.id
      assert_person_addresses(person.person_addresses, resp["data"]["addresses"])
      assert [] == resp["data"]["addresses"]
    end

    test "update person by id without addresses in params", %{conn: conn} do
      person =
        insert(:mpi, :person,
          first_name: "Святославович",
          addresses: [build(:address, settlement: "Ромни")],
          person_addresses: []
        )

      assert resp =
               conn
               |> put(person_path(conn, :update, person.id), %{first_name: "Володиир"})
               |> json_response(200)

      assert %Person{
               person_addresses: [
                 %Core.PersonAddress{
                   person_first_name: "Володиир",
                   settlement: "Ромни"
                 }
               ]
             } = PersonsAPI.get_by_id(resp["data"]["id"])
    end

    test "update by id adresses for existing person with addresses and without person_addresses", %{conn: conn} do
      person = insert(:mpi, :person, addresses: [build(:address, settlement: "Київ")], person_addresses: [])
      addresses = [build(:address, settlement: "Коростень")]

      assert resp =
               conn
               |> put(person_path(conn, :update, person.id), %{
                 first_name: "Ольга",
                 last_name: "Ігорівна",
                 addresses: addresses
               })
               |> json_response(200)

      assert_person_addresses(addresses, resp["data"]["addresses"])
      assert [%{"settlement" => "Коростень"}] = resp["data"]["addresses"]

      assert %Person{
               person_addresses: [
                 %Core.PersonAddress{
                   person_first_name: "Ольга",
                   person_last_name: "Ігорівна",
                   settlement: "Коростень"
                 }
               ]
             } = PersonsAPI.get_by_id(person.id)
    end

    test "update adresses for existing person with addresses and with person_addresses", %{conn: conn} do
      person =
        insert(:mpi, :person,
          addresses: [build(:address, settlement: "Київ")],
          person_addresses: [build(:address, settlement: "Київ")]
        )

      addresses = [build(:address, settlement: "Вишгород")]

      assert resp =
               conn
               |> put(person_path(conn, :update, person.id), %{
                 first_name: "Ярослав",
                 last_name: "Володимирович",
                 addresses: addresses
               })
               |> json_response(200)

      assert_person_addresses(addresses, resp["data"]["addresses"])
      assert [%{"settlement" => "Вишгород"}] = resp["data"]["addresses"]

      assert %Person{
               person_addresses: [
                 %Core.PersonAddress{
                   person_first_name: "Ярослав",
                   person_last_name: "Володимирович",
                   settlement: "Вишгород"
                 }
               ]
             } = PersonsAPI.get_by_id(person.id)
    end

    test "update adresses for existing person with addresses and person_addresses and without addresses in params do not double person_addresses",
         %{
           conn: conn
         } do
      person =
        insert(:mpi, :person,
          addresses: [build(:address, settlement: "Хотин")],
          person_addresses: [build(:address, settlement: "Хотин")]
        )

      assert resp =
               conn
               |> put(person_path(conn, :update, person.id), %{
                 first_name: "Олександр",
                 last_name: "Коваль"
               })
               |> json_response(200)

      assert [%{"settlement" => "Хотин"}] = resp["data"]["addresses"]

      assert %Person{
               person_addresses: [
                 %Core.PersonAddress{
                   person_first_name: "Олександр",
                   person_last_name: "Коваль",
                   settlement: "Хотин"
                 }
               ]
             } = PersonsAPI.get_by_id(person.id)
    end

    test "create person with addresses", %{conn: conn} do
      addresses = [build(:address, settlement: "Львів", region: "Галичина")]

      person_data =
        string_params_for(:person,
          first_name: "Данило",
          second_name: "Романович",
          last_name: "Галицький",
          addresses: addresses,
          person_addresses: nil
        )

      assert data =
               conn
               |> post(person_path(conn, :create), person_data)
               |> json_response(201)
               |> Map.get("data")

      assert_person_addresses(addresses, data["addresses"])
      assert [%{"settlement" => "Львів", "region" => "Галичина"}] = data["addresses"]

      assert %Person{
               person_addresses: [
                 %Core.PersonAddress{
                   person_first_name: "Данило",
                   person_last_name: "Галицький",
                   region: "Галичина",
                   settlement: "Львів"
                 }
               ]
             } = PersonsAPI.get_by_id(data["id"])
    end
  end
end
