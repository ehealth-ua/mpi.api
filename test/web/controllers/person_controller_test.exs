defmodule MPI.Web.PersonControllerTest do
  @moduledoc false

  use MPI.Web.ConnCase
  import MPI.Factory

  test "GET /persons/:id OK", %{conn: conn} do
    person = insert(:person)

    res =
      conn
      |> get("/persons/#{person.id}")
      |> json_response(200)

    assert res["data"]

    person =
      person
      |> Poison.encode!()
      |> Poison.decode!()

    assert person == res["data"]

    assert_person(res["data"])
  end

  test "GET /persons/not_found", %{conn: conn} do
    response =
      conn
      |> get("/persons/9fa323da-37e1-4789-87f1-8776999d5196")
      |> json_response(404)
      |> Map.fetch!("error")

    assert response == %{"type" => "not_found"}
  end

  test "POST /persons/ OK", %{conn: conn} do
    person_data = :person |> build() |> Map.from_struct()

    res =
      conn
      |> post("/persons/", person_data)
      |> json_response(201)

    assert_person(res["data"])

    res =
      conn
      |> get("/persons/#{res["data"]["id"]}")
      |> json_response(200)

    assert_person(res["data"])
  end

  describe "create or update person" do
    test "success create and update person", %{conn: conn} do
      person_data =
        :person
        |> build()
        |> Map.from_struct()
        |> Map.put(:first_name, "test1")

      person_created =
        conn
        |> post("/persons/", person_data)
        |> json_response(201)

      assert_person(person_created["data"])

      person_data =
        person_data
        |> Map.put(:birth_country, "some-changed-birth-country")
        |> Map.put(:phones, [%{"type" => "MOBILE", "number" => "+38#{Enum.random(1_000_000_000..9_999_999_999)}"}])
        |> Map.put(:id, person_created["data"]["id"])

      res =
        conn
        |> post("/persons/", person_data)
        |> json_response(200)

      assert_person(res["data"])

      res =
        conn
        |> get("/persons/#{person_created["data"]["id"]}")
        |> json_response(200)

      assert res["data"]

      assert res["data"]["birth_country"] == "some-changed-birth-country"
    end

    test "person not found", %{conn: conn} do
      assert conn
             |> post("/persons/", %{"id" => Ecto.UUID.generate()})
             |> json_response(404)
    end

    test "person is not active", %{conn: conn} do
      person = insert(:person, is_active: false)

      assert conn
             |> post("/persons/", %{"id" => person.id})
             |> json_response(409)
    end
  end

  test "POST /persons/ 422", %{conn: conn} do
    error =
      conn
      |> post("/persons/", %{})
      |> json_response(422)
      |> Map.fetch!("error")

    assert error["type"] == "validation_failed"
  end

  test "HEAD /persons/:id OK", %{conn: conn} do
    person = insert(:person)

    status =
      conn
      |> head("/persons/#{person.id}")
      |> Map.fetch!(:status)

    assert status == 200
  end

  test "HEAD /persons/not_found OK", %{conn: conn} do
    status =
      conn
      |> head("/persons/9fa323da-37e1-4789-87f1-8776999d5196")
      |> Map.fetch!(:status)

    assert status == 404
  end

  test "PUT /persons/:id OK", %{conn: conn} do
    person = insert(:person)
    person_data = :person |> build() |> Map.from_struct()

    res =
      conn
      |> put("/persons/#{person.id}", person_data)
      |> json_response(200)

    assert res["data"]
    assert_person(res["data"])
  end

  describe "reset auth method" do
    test "success", %{conn: conn} do
      person = insert(:person)

      res =
        conn
        |> patch("/persons/#{person.id}/actions/reset_auth_method")
        |> json_response(200)

      assert res["data"]
      assert_person(res["data"])
      assert [%{"type" => "NA"}] == res["data"]["authentication_methods"]
    end

    test "invalid status", %{conn: conn} do
      person = insert(:person, status: "INACTIVE")

      conn
      |> patch("/persons/#{person.id}/actions/reset_auth_method")
      |> json_response(409)
    end
  end

  test "PUT /persons/not_found", %{conn: conn} do
    response =
      conn
      |> put("/persons/9fa323da-37e1-4789-87f1-8776999d5196", %{})
      |> json_response(404)
      |> Map.fetch!("error")

    assert response == %{"type" => "not_found"}
  end

  test "PATCH /persons/:id", %{conn: conn} do
    merged_id1 = "cbe38ac6-a258-4b5d-b684-db53a4f54192"
    merged_id2 = "1190cd3a-18f0-4e0a-98d6-186cd6da145c"
    person = insert(:person, merged_ids: [merged_id1])

    patch(conn, "/persons/#{person.id}", Poison.encode!(%{merged_ids: [merged_id2]}))

    assert [^merged_id1, ^merged_id2] = MPI.Repo.get(MPI.Person, person.id).merged_ids
  end

  test "GET /persons/ SEARCH by last_name 200", %{conn: conn} do
    person = insert(:person, phones: nil)

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

    Enum.each(data, fn person ->
      refute Map.has_key?(person, "phone_number")
    end)
  end

  test "GET /persons/ SEARCH by ids 200", %{conn: conn} do
    %{id: id_1} = insert(:person)
    %{id: id_2} = insert(:person)
    %{id: id_3} = insert(:person, is_active: false)
    %{id: id_4} = insert(:person, status: "INACTIVE")
    %{id: id_5} = insert(:person, status: "MERGED")

    ids = [id_1, id_2, id_3, id_4, id_5]

    conn = get(conn, person_path(conn, :index, ids: Enum.join(ids, ","), status: "active", limit: 3))
    data = json_response(conn, 200)["data"]
    assert 2 == length(data)

    Enum.each(data, fn person ->
      assert person["id"] in [id_1, id_2]
      assert Map.has_key?(person, "first_name")
      assert Map.has_key?(person, "second_name")
      assert Map.has_key?(person, "last_name")
    end)
  end

  test "GET /persons/ empty search", %{conn: conn} do
    conn = get(conn, person_path(conn, :index, ids: ""))
    assert [] == json_response(conn, 200)["data"]
  end

  test "GET /persons/ SEARCH 200", %{conn: conn} do
    person = insert(:person, phones: [build(:phone, type: "LANDLINE"), build(:phone, type: "MOBILE")])

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
             data |> hd |> Map.take(Map.keys(search_params))

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
    assert Enum.into(params, %{}, fn {k, v} -> {k, String.downcase(v)} end) == data |> hd |> Map.take(Map.keys(params))

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
             "national_id" => _,
             "death_date" => _,
             "preferred_way_communication" => _,
             "tax_id" => _,
             "invalid_tax_id" => _,
             "updated_at" => _,
             "updated_by" => _,
             "birth_country" => _,
             "birth_settlement" => _,
             "addresses" => _,
             "documents" => _,
             "phones" => _,
             "secret" => _,
             "emergency_contact" => _,
             "confidant_person" => _,
             "status" => _,
             "patient_signed" => _,
             "process_disclosure_data_consent" => _,
             "authentication_methods" => _,
             "merged_ids" => _
           } = data

    assert is_list(data["merged_ids"])
  end

  def assert_person_search(data) do
    Enum.each(data, fn person ->
      assert %{
               "id" => _,
               "birth_date" => _
             } = person
    end)

    data
  end
end
