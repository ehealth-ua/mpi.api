defmodule MPI.Web.PersonControllerTest do
  @moduledoc false

  use MPI.Web.ConnCase
  import Core.Factory
  alias Core.Person
  alias Core.PersonAddress
  alias Core.PersonDocument
  alias Core.Persons.PersonsAPI
  alias Core.PersonPhone
  alias Ecto.UUID

  def is_equal?(key, person_key, attributes, data) do
    %{^person_key => db_data} = PersonsAPI.get_by_id(data["id"])

    case {data[key], db_data} do
      {nil, []} ->
        true

      {person_data, db_data} ->
        process_items = fn person_data_s ->
          for item <- person_data_s,
              into: [],
              do:
                item
                |> Poison.encode!()
                |> Poison.decode!()
                |> Map.take(attributes)
        end

        processed_data = process_items.(person_data)
        person_db_data = process_items.(db_data)
        filtered = Enum.filter(processed_data, fn v -> !Enum.member?(person_db_data, v) end)

        assert filtered == []
    end
  end

  defp json_person_attributes?(data) do
    is_equal?("phones", :phones, ["number", "type"], data) &&
      is_equal?("documents", :documents, ["number", "type"], data) &&
      is_equal?("authentication_methods", :person_authentication_methods, ["phone_number", "type"], data)
  end

  test "successful show person, auth methods are sorted by updated_at", %{conn: conn} do
    updated_at = DateTime.add(DateTime.utc_now(), -60, :second)

    person =
      insert(
        :mpi,
        :person,
        person_authentication_methods: [
          build(:authentication_method,
            type: "OTP",
            phone_number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}",
            updated_at: updated_at
          ),
          build(:authentication_method, type: "OFFLINE")
        ]
      )

    resp =
      conn
      |> get(person_path(conn, :show, person.id))
      |> json_response(200)

    assert resp["data"]["id"] == person.id
    json_person_attributes?(resp["data"])
    assert_person(resp["data"])

    {:ok, last_updated_at, _} =
      resp
      |> get_in(~w(data authentication_methods))
      |> hd()
      |> Map.get("updated_at")
      |> DateTime.from_iso8601()

    assert DateTime.compare(last_updated_at, updated_at) == :gt
  end

  test "successful show person when person_authentication_methods attr is empty", %{conn: conn} do
    person =
      insert(
        :mpi,
        :person,
        person_authentication_methods: []
      )

    resp =
      conn
      |> get(person_path(conn, :show, person.id))
      |> json_response(200)

    assert resp["data"]["id"] == person.id
    assert_person(resp["data"])
    assert person.authentication_methods == get_in(resp, ~w(data authentication_methods))
  end

  test "person is not found", %{conn: conn} do
    response =
      conn
      |> get(person_path(conn, :show, UUID.generate()))
      |> json_response(404)
      |> Map.fetch!("error")

    assert response == %{"type" => "not_found"}
  end

  test "successful create person", %{conn: conn} do
    person_data =
      :person
      |> string_params_for()
      |> Map.delete("person_authentication_methods")

    resp =
      conn
      |> post(person_path(conn, :create), person_data)
      |> json_response(201)

    assert_person(resp["data"])

    resp =
      conn
      |> get(person_path(conn, :show, resp["data"]["id"]))
      |> json_response(200)

    json_person_attributes?(resp["data"])
    resp["data"]["documents"]
    assert_person(resp["data"])
  end

  test "spaces are trimmed when person is created", %{conn: conn} do
    person_data =
      string_params_for(:person, %{
        first_name: "   first   name ",
        second_name: "  second name",
        last_name: "last name  "
      })
      |> Map.delete("person_authentication_methods")

    resp =
      conn
      |> post(person_path(conn, :create), person_data)
      |> json_response(201)

    assert_person(resp["data"])

    resp =
      conn
      |> get(person_path(conn, :show, resp["data"]["id"]))
      |> json_response(200)

    json_person_attributes?(resp["data"])

    assert_person(resp["data"])
    assert "first name" == resp["data"]["first_name"]
    assert "second name" == resp["data"]["second_name"]
    assert "last name" == resp["data"]["last_name"]
  end

  test "successful create person with inserted_by, updated_by by x-consumer-id without merge candidates", %{conn: conn} do
    user_id = UUID.generate()

    person_data =
      :person
      |> string_params_for()
      |> Map.drop(~w(phones merged_persons master_person person_authentication_methods))

    resp =
      conn
      |> put_req_header("x-consumer-id", user_id)
      |> post(person_path(conn, :create), person_data)
      |> json_response(201)

    assert_person(resp["data"])
    assert resp["data"]["inserted_by"] == user_id
    assert resp["data"]["updated_by"] == user_id
    refute resp["data"]["master_person"]
    assert [] == resp["data"]["merged_persons"]
  end

  test "successful create person without phones", %{conn: conn} do
    person_data =
      :person
      |> string_params_for()
      |> Map.drop(~w(phones person_authentication_methods))

    resp =
      conn
      |> post(person_path(conn, :create), person_data)
      |> json_response(201)

    assert_person(resp["data"])

    resp =
      conn
      |> get(person_path(conn, :show, resp["data"]["id"]))
      |> json_response(200)

    json_person_attributes?(resp["data"])
    assert_person(resp["data"])
  end

  test "creation person without documents failed", %{conn: conn} do
    person_data =
      :person
      |> string_params_for()
      |> Map.drop(~w(documents person_authentication_methods))

    resp =
      conn
      |> post(person_path(conn, :create), person_data)
      |> json_response(422)

    assert %{
             "invalid" => [
               %{
                 "entry" => "$.documents",
                 "rules" => [
                   %{
                     "description" => "can't be blank",
                     "params" => [],
                     "rule" => "required"
                   }
                 ]
               }
             ],
             "type" => "validation_failed"
           } = resp["error"]
  end

  describe "create or update person with unzr" do
    test "success update person and update unzr ignore documents and check updated_by and inserted_by user",
         %{
           conn: conn
         } do
      inserted_by_id = UUID.generate()
      update_by_id = UUID.generate()
      document = build(:document, type: "NATIONAL_ID")
      person = insert(:mpi, :person, unzr: "19910827-33445", inserted_by: inserted_by_id)

      person_data =
        %{person | documents: [document], unzr: "20160828-33445"}
        |> Poison.encode!()
        |> Poison.decode!()

      person_updated =
        conn
        |> put_req_header("x-consumer-id", update_by_id)
        |> post(person_path(conn, :create), person_data)
        |> json_response(200)

      assert "20160828-33445" == person_updated["data"]["unzr"]
      assert_person(person_updated["data"])

      assert person_updated["data"]["inserted_by"] == inserted_by_id
      assert person_updated["data"]["updated_by"] == update_by_id
    end

    test "success update person documents without unzr do not change person's unzr", %{conn: conn} do
      document = build(:document, type: "PASSPORT")
      person = insert(:mpi, :person, unzr: "20160303-33445")

      person_data =
        %{person | documents: [document]}
        |> Poison.encode!()
        |> Poison.decode!()

      person_updated =
        conn
        |> post(person_path(conn, :create), person_data)
        |> json_response(200)

      assert "20160303-33445" == person_updated["data"]["unzr"]
      assert_person(person_updated["data"])
    end
  end

  describe "test first API declaration requests eheath" do
    test "success create person without no_tax_id", %{conn: conn} do
      person_data =
        :person
        |> string_params_for()
        |> Map.drop(~w(no_tax_id person_authentication_methods))

      person_created =
        conn
        |> post(person_path(conn, :create), person_data)
        |> json_response(201)

      assert_person(person_created["data"])
    end

    test "success create person without without unzr with NATIONAL_ID document", %{conn: conn} do
      document = build(:document, type: "NATIONAL_ID")

      person =
        :person
        |> string_params_for(documents: [document])
        |> Map.drop(~w(unzr person_authentication_methods))

      person_created =
        conn
        |> post(person_path(conn, :create), person)
        |> json_response(201)

      assert_person(person_created["data"])
    end
  end

  describe "create or update person" do
    test "success create and update person", %{conn: conn} do
      person_data =
        :person
        |> string_params_for()
        |> Map.put("first_name", "test1")
        |> Map.delete("person_authentication_methods")

      person_created =
        conn
        |> post(person_path(conn, :create), person_data)
        |> json_response(201)

      assert_person(person_created["data"])

      assert resp =
               conn
               |> post(person_path(conn, :create), person_data)
               |> json_response(409)

      assert %{
               "error" => %{
                 "message" => "Such person already exists",
                 "type" => "request_conflict"
               }
             } = resp

      person_data =
        person_data
        |> Map.put("birth_country", "some-changed-birth-country")
        |> Map.put("phones", [
          %{"type" => "MOBILE", "number" => "+38#{Enum.random(1_000_000_000..9_999_999_999)}"}
        ])
        |> Map.put("id", person_created["data"]["id"])

      resp =
        conn
        |> post(person_path(conn, :create), person_data)
        |> json_response(200)

      assert_person(resp["data"])

      resp =
        conn
        |> get(person_path(conn, :show, person_created["data"]["id"]))
        |> json_response(200)

      assert resp["data"]
      json_person_attributes?(resp["data"])
      assert resp["data"]["birth_country"] == "some-changed-birth-country"
    end

    test "person not found", %{conn: conn} do
      assert conn
             |> post(person_path(conn, :create), %{"id" => Ecto.UUID.generate()})
             |> json_response(404)
    end

    test "person is not active", %{conn: conn} do
      person = insert(:mpi, :person, is_active: false)

      assert conn
             |> post(person_path(conn, :create), %{"id" => person.id})
             |> json_response(409)
    end
  end

  describe "addresses and person_adresses" do
    test "update by id adresses for existing person with addresses", %{conn: conn} do
      person = insert(:mpi, :person, addresses: [build(:person_address, settlement: "Київ")])
      addresses = [string_params_for(:person_address, settlement: "Коростень")]

      assert resp =
               conn
               |> put(person_path(conn, :update, person.id), %{
                 first_name: "Ольга",
                 last_name: "Ігорівна",
                 addresses: addresses
               })
               |> json_response(200)

      assert [%{"settlement" => "Коростень"}] = resp["data"]["addresses"]
      assert %Person{addresses: [%Core.PersonAddress{settlement: "Коростень"}]} = PersonsAPI.get_by_id(person.id)
    end
  end

  test "person update without params failed", %{conn: conn} do
    error =
      conn
      |> post(person_path(conn, :create), %{})
      |> json_response(422)
      |> Map.fetch!("error")

    assert error["type"] == "validation_failed"
  end

  test "create person failed on authentication_methods constraint", %{conn: conn} do
    auth_method = build(:authentication_method)

    person_data =
      :person
      |> string_params_for(
        person_authentication_methods: [auth_method, auth_method],
        authentication_methods: array_of_map([auth_method, auth_method])
      )
      |> Map.delete("person_authentication_methods")

    conn
    |> post(person_path(conn, :create), person_data)
    |> json_response(422)
  end

  test "create person failed when OTP authentication_methods does not contain phone_number", %{conn: conn} do
    authentication_methods = [build(:authentication_method, type: "OTP", phone_number: nil)]

    person_data =
      :person
      |> string_params_for(
        person_authentication_methods: authentication_methods,
        authentication_methods: array_of_map(authentication_methods)
      )
      |> Map.delete("person_authentication_methods")

    conn
    |> post(person_path(conn, :create), person_data)
    |> json_response(422)
  end

  test "HEAD /persons/:id OK", %{conn: conn} do
    person = insert(:mpi, :person)

    status =
      conn
      |> head("/persons/#{person.id}")
      |> Map.fetch!(:status)

    assert status == 200
  end

  test "HEAD /persons/not_found OK", %{conn: conn} do
    status =
      conn
      |> head("/persons/#{UUID.generate()}")
      |> Map.fetch!(:status)

    assert status == 404
  end

  test "successful update person", %{conn: conn} do
    person = insert(:mpi, :person)

    person_data =
      :person
      |> string_params_for()
      |> Map.delete("person_authentication_methods")

    resp =
      conn
      |> put(person_path(conn, :update, person.id), person_data)
      |> json_response(200)

    assert resp["data"]
    json_person_attributes?(resp["data"])
    assert_person(resp["data"])
  end

  test "update person does not change merged links", %{conn: conn} do
    person = insert(:mpi, :person, merged_persons: build_list(3, :merged_pairs), master_person: build(:merged_pairs))

    resp =
      conn
      |> put(person_path(conn, :update, person.id), %{tax_id: "1234567890"})
      |> json_response(200)

    assert resp["data"]
    json_person_attributes?(resp["data"])
    assert_person(resp["data"])
    assert 3 == Enum.count(resp["data"]["merged_persons"])
    assert %{} = resp["data"]["master_person"]
  end

  test "spaces are trimmed when person is updated", %{conn: conn} do
    person = insert(:mpi, :person)

    person_data =
      :person
      |> string_params_for(%{
        first_name: "   first   name ",
        second_name: "  second name",
        last_name: "last name  "
      })
      |> Map.delete("person_authentication_methods")

    resp =
      conn
      |> put(person_path(conn, :update, person.id), person_data)
      |> json_response(200)

    assert resp["data"]
    json_person_attributes?(resp["data"])
    assert_person(resp["data"])
    assert "first name" == resp["data"]["first_name"]
    assert "second name" == resp["data"]["second_name"]
    assert "last name" == resp["data"]["last_name"]
  end

  describe "reset auth method" do
    test "success", %{conn: conn} do
      person = insert(:mpi, :person)

      resp =
        conn
        |> patch(person_path(conn, :reset_auth_method, person.id))
        |> json_response(200)

      assert resp["data"]
      assert_person(resp["data"])
      assert "NA" == hd(resp["data"]["authentication_methods"])["type"]
    end

    test "invalid status", %{conn: conn} do
      person = insert(:mpi, :person, status: Person.status(:inactive))

      conn
      |> patch(person_path(conn, :reset_auth_method, person.id))
      |> json_response(409)
    end

    test "not found", %{conn: conn} do
      conn
      |> patch(person_path(conn, :reset_auth_method, UUID.generate()))
      |> assert_not_found()
    end
  end

  test "update not-found person failed", %{conn: conn} do
    conn
    |> put(person_path(conn, :update, UUID.generate()), %{})
    |> assert_not_found()
  end

  test "update person failed on authentication_methods constraint", %{conn: conn} do
    person = insert(:mpi, :person)

    auth_method = build(:authentication_method)

    person_data =
      :person
      |> string_params_for(
        person_authentication_methods: [auth_method, auth_method],
        authentication_methods: array_of_map([auth_method, auth_method])
      )
      |> Map.delete("person_authentication_methods")

    conn
    |> put(person_path(conn, :update, person.id), person_data)
    |> json_response(422)
  end

  test "update person failed when OTP authentication_methods does not contain phone_number", %{conn: conn} do
    person = insert(:mpi, :person)

    authentication_methods = [build(:authentication_method, type: "OTP", phone_number: nil)]

    person_data =
      :person
      |> string_params_for(
        person_authentication_methods: authentication_methods,
        authentication_methods: array_of_map(authentication_methods)
      )
      |> Map.delete("person_authentication_methods")

    conn
    |> put(person_path(conn, :update, person.id), person_data)
    |> json_response(422)
  end

  test "successful persons search by last_name", %{conn: conn} do
    person = insert(:mpi, :person, phones: [])

    conn =
      get(
        conn,
        person_path(
          conn,
          :index,
          last_name: person.last_name,
          first_name: person.first_name,
          birth_date: to_string(person.birth_date)
        )
      )

    data = json_response(conn, 200)["data"]
    assert 1 == length(data)

    for data_item <- data, do: json_person_attributes?(data_item)

    Enum.each(data, fn person ->
      refute Map.has_key?(person, "phone_number")
    end)
  end

  test "successful persons search by tax_id", %{conn: conn} do
    person = insert(:mpi, :person)
    tax_id = person.tax_id

    conn =
      get(
        conn,
        person_path(
          conn,
          :index,
          number: tax_id,
          type: "tax_id"
        )
      )

    data = json_response(conn, 200)["data"]
    assert 1 == length(data)

    Enum.each(data, fn person ->
      assert tax_id == person["tax_id"]
    end)
  end

  test "successful persons search by document number", %{conn: conn} do
    insert(:mpi, :person, documents: [build(:person_document, type: "PASSPORT", number: "iI9922Kk")])

    assert data =
             conn
             |> get(person_path(conn, :index, number: "II9922KK", type: "PASSPORT"))
             |> json_response(200)
             |> Map.get("data")

    assert 1 == length(data)
    assert "iI9922Kk" == hd(hd(data)["documents"])["number"]
  end

  test "successful persons search by auth_phone_number", %{conn: conn} do
    %{id: person_id} =
      insert(:mpi, :person,
        person_authentication_methods: [build(:authentication_method, type: "OTP", phone_number: "123")]
      )

    auth_phone_number = "123"

    insert(
      :mpi,
      :person,
      authentication_methods: [%{phone_number: auth_phone_number}],
      status: Person.status(:inactive)
    )

    resp_data =
      conn
      |> get(person_path(conn, :index, auth_phone_number: auth_phone_number))
      |> json_response(200)
      |> Map.get("data")

    assert [%{"id" => ^person_id}] = resp_data
  end

  test "successful persons search by unzr as type number", %{conn: conn} do
    person = insert(:mpi, :person)
    unzr = person.unzr

    conn =
      get(
        conn,
        person_path(
          conn,
          :index,
          number: unzr,
          type: "unzr"
        )
      )

    data = json_response(conn, 200)["data"]
    assert 1 == length(data)

    Enum.each(data, fn person ->
      assert unzr == person["unzr"]
    end)
  end

  test "successful persons search by unzr as parametr", %{conn: conn} do
    person = insert(:mpi, :person)
    unzr = person.unzr

    conn =
      get(
        conn,
        person_path(
          conn,
          :index,
          unzr: unzr
        )
      )

    data = json_response(conn, 200)["data"]
    assert 1 == length(data)

    Enum.each(data, fn person ->
      assert unzr == person["unzr"]
    end)
  end

  test "successful persons search by unzr, tax_id, birthday as parameters when person has no unzr but has tax_id",
       %{
         conn: conn
       } do
    person = insert(:mpi, :person, unzr: nil)
    tax_id = person.tax_id

    conn =
      get(
        conn,
        person_path(
          conn,
          :index,
          tax_id: tax_id
        )
      )

    data = json_response(conn, 200)["data"]
    assert 1 == length(data)

    Enum.each(data, fn person ->
      assert tax_id == person["tax_id"]
    end)
  end

  test "successful persons search by ids", %{conn: conn} do
    %{id: id_1} = insert(:mpi, :person)
    %{id: id_2} = insert(:mpi, :person)
    %{id: id_3} = insert(:mpi, :person, is_active: false)
    %{id: id_4} = insert(:mpi, :person, status: "INACTIVE")
    %{id: id_5} = insert(:mpi, :person, status: "MERGED")

    ids = [id_1, id_2, id_3, id_4, id_5]

    assert resp =
             conn
             |> get(person_path(conn, :index, ids: Enum.join(ids, ","), status: "active"))
             |> json_response(200)

    data = resp["data"]
    assert 2 == length(data)

    Enum.each(data, fn person ->
      assert person["id"] in [id_1, id_2]
      assert Map.has_key?(person, "first_name")
      assert Map.has_key?(person, "second_name")
      assert Map.has_key?(person, "last_name")
    end)
  end

  test "successful persons search by first_name, second_name and last_name with extra spaces", %{
    conn: conn
  } do
    person =
      insert(
        :mpi,
        :person,
        first_name: "first name",
        second_name: "second name",
        last_name: "last name"
      )

    conn =
      get(
        conn,
        person_path(
          conn,
          :index,
          first_name: "   first   name ",
          second_name: "  second name",
          last_name: "last name  "
        )
      )

    data = json_response(conn, 200)["data"]
    assert 1 == length(data)

    Enum.each(data, fn found_person ->
      assert person.first_name == found_person["first_name"]
      assert person.second_name == found_person["second_name"]
      assert person.last_name == found_person["last_name"]
    end)
  end

  test "empty search", %{conn: conn} do
    conn = get(conn, person_path(conn, :index, ids: ""))
    assert [] == json_response(conn, 200)["data"]
  end

  test "search persons by search params returns all preloaded fields", %{conn: conn} do
    person = insert(:mpi, :person, merged_persons: build_list(3, :merged_pairs), master_person: build(:merged_pairs))

    search_params = %{
      "first_name" => person.first_name,
      "last_name" => person.last_name,
      "birth_date" => to_string(person.birth_date)
    }

    data =
      conn
      |> get(person_path(conn, :index), search_params)
      |> json_response(200)
      |> Map.get("data")
      |> assert_person_search()

    preloaded_data = data |> hd |> Map.take(~w(documents phones addresses merged_persons master_person))
    assert 3 == Enum.count(preloaded_data["merged_persons"])
    assert is_map(preloaded_data["master_person"])
    assert 2 == Enum.count(preloaded_data["documents"])
    assert 1 == Enum.count(preloaded_data["phones"])
    assert 2 == Enum.count(preloaded_data["addresses"])
  end

  test "successful person search", %{conn: conn} do
    person =
      insert(
        :mpi,
        :person,
        documents: [build(:document, type: "BIRTH_CERTIFICATE", number: "1234567890")],
        phones: [build(:phone, type: "LANDLINE"), build(:phone, type: "MOBILE")]
      )

    search_params = %{
      "first_name" => person.first_name,
      "last_name" => person.last_name,
      "birth_date" => to_string(person.birth_date)
    }

    data =
      conn
      |> get(person_path(conn, :index), search_params)
      |> json_response(200)
      |> Map.get("data")
      |> assert_person_search()

    assert 1 == Enum.count(data)
    assert search_params == data |> hd |> Map.take(Map.keys(search_params))

    search_params_bc = %{
      "first_name" => person.first_name,
      "last_name" => person.last_name,
      "birth_date" => to_string(person.birth_date),
      "birth_certificate" => "1234567890"
    }

    data =
      conn
      |> get(person_path(conn, :index), search_params_bc)
      |> json_response(200)
      |> Map.get("data")
      |> assert_person_search()

    assert 1 == Enum.count(data)

    search_params_bc = %{
      "first_name" => person.first_name,
      "last_name" => person.last_name,
      "birth_date" => to_string(person.birth_date),
      "birth_certificate" => "0123456789"
    }

    data_no_bc =
      conn
      |> get(person_path(conn, :index), search_params_bc)
      |> json_response(200)
      |> Map.get("data")
      |> assert_person_search()

    assert data_no_bc == []

    assert search_params == data |> hd |> Map.take(Map.keys(search_params))

    search_params =
      search_params
      |> Map.put("second_name", String.upcase(person.second_name))
      |> Map.put("tax_id", person.tax_id)

    data =
      conn
      |> get(person_path(conn, :index), search_params)
      |> json_response(200)
      |> Map.get("data")
      |> assert_person_search()

    assert 1 == Enum.count(data)

    assert Enum.into(search_params, %{}, fn {k, v} -> {k, String.downcase(v)} end) ==
             data
             |> hd
             |> Map.take(Map.keys(search_params))
             |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, k, String.downcase(v)) end)

    # Getting mobile phone number because search uses just it
    phone_number =
      person
      |> Map.fetch!(:phones)
      |> Enum.filter(fn phone -> phone.type == "MOBILE" end)
      |> List.first()
      |> Map.fetch!(:number)

    search_params = Map.put(search_params, "phone_number", phone_number)

    data =
      conn
      |> get(person_path(conn, :index), search_params)
      |> json_response(200)
      |> Map.get("data")
      |> assert_person_search()

    assert 1 == Enum.count(data)
    params = Map.delete(search_params, "phone_number")

    assert Enum.into(params, %{}, fn {k, v} -> {k, String.downcase(v)} end) ==
             data
             |> hd
             |> Map.take(Map.keys(params))
             |> Enum.reduce(%{}, fn {k, v}, acc -> Map.put(acc, k, String.downcase(v)) end)

    search_params =
      search_params
      |> Map.put("second_name", person.second_name)
      |> Map.put("tax_id", "not_found")

    assert [] =
             conn
             |> get(person_path(conn, :index), search_params)
             |> json_response(200)
             |> Map.get("data")
             |> assert_person_search()
  end

  defp assert_person(data) do
    assert %{
             "id" => _,
             "version" => _,
             "first_name" => _,
             "last_name" => _,
             "second_name" => _,
             "email" => _,
             "gender" => _,
             "inserted_at" => _,
             "inserted_by" => _,
             "is_active" => true,
             "birth_date" => _,
             "unzr" => _,
             "death_date" => _,
             "preferred_way_communication" => _,
             "tax_id" => _,
             "invalid_tax_id" => _,
             "updated_at" => _,
             "updated_by" => _,
             "birth_country" => _,
             "birth_settlement" => _,
             "secret" => _,
             "emergency_contact" => _,
             "confidant_person" => _,
             "status" => _,
             "patient_signed" => _,
             "process_disclosure_data_consent" => _,
             "authentication_methods" => _,
             "merged_persons" => _,
             "master_person" => _,
             "addresses" => _,
             "documents" => _,
             "phones" => _
           } = data

    assert is_list(data["merged_persons"])
    assert Map.has_key?(data, "master_person")
    assert is_nil(data["master_person"]) or is_map(data["master_person"])
    assert is_list(data["documents"])

    Enum.each(data["documents"], &assert_document(&1))
    Enum.each(data["phones"], &assert_phone(&1))
    Enum.each(data["addresses"], &assert_address(&1))
    Enum.each(data["merged_persons"], &assert_merged_persons(&1))
    assert_master_person(data["master_person"])
  end

  defp assert_phone(phone), do: assert_keys(PersonPhone.fields(), phone)
  defp assert_document(document), do: assert_keys(PersonDocument.fields(), document)
  defp assert_address(address), do: assert_keys(PersonAddress.fields(), address)
  defp assert_master_person(nil), do: true
  defp assert_master_person(master_person), do: assert_keys(~w(person_id master_person_id), master_person)
  defp assert_merged_persons(nil), do: true
  defp assert_merged_persons(merged_person), do: assert_keys(~w(person_id merge_person_id), merged_person)

  defp assert_keys(fields, entities) do
    Enum.each(fields, fn field -> assert Map.has_key?(entities, to_string(field)) end)
  end

  defp assert_person_search(data) do
    for person <- data do
      assert %{"id" => _, "birth_date" => _} = person
    end

    data
  end

  defp assert_not_found(conn) do
    response =
      conn
      |> json_response(404)
      |> Map.fetch("error")

    assert {:ok, %{"type" => "not_found"}} === response
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
