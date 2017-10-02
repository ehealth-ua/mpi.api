defmodule MPI.Web.PersonControllerTest do
  use MPI.Web.ConnCase
  alias MPI.Factory

  test "GET /persons/:id OK", %{conn: conn} do
    person = :person |> Factory.insert() |> Map.put(:merged_ids, [])

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
    person_data = Factory.build_factory_params(:person_params)

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

  test "Create or update Person", %{conn: conn} do
    person_data = Factory.build_factory_params(:person_params)

    person_created =
      conn
      |> post("/persons/", person_data)
      |> json_response(201)

    assert_person(person_created["data"])

    person_data =
      person_data
      |> Map.put(:birth_country, "some-changed-birth-country")
      |> Map.put(:phones, [%{"type" => "MOBILE", "number" => "+38#{Enum.random(1_000_000_000..9_999_999_999)}"}])

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

  test "POST /persons/ 422", %{conn: conn} do
    error =
      conn
      |> post("/persons/", %{})
      |> json_response(422)
      |> Map.fetch!("error")

    assert error["type"] == "validation_failed"
  end

  test "HEAD /persons/:id OK", %{conn: conn} do
    person = Factory.insert(:person)
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
    person = Factory.insert(:person)
    person_data = Factory.build_factory_params(:person_params)

    res =
      conn
      |> put("/persons/#{person.id}", person_data)
      |> json_response(200)

    assert res["data"]
    assert_person(res["data"])
  end

  test "PUT /persons/not_found", %{conn: conn} do
    response =
      conn
      |> put("/persons/9fa323da-37e1-4789-87f1-8776999d5196", %{})
      |> json_response(404)
      |> Map.fetch!("error")

    assert response == %{"type" => "not_found"}
  end

  test "GET /persons/ SEARCH 422", %{conn: conn} do
    error =
      conn
      |> get("/persons/")
      |> json_response(422)
      |> Map.fetch!("error")

    assert error["type"] == "validation_failed"

    Enum.each(error["invalid"], fn(%{"entry_type" => entry_type}) ->
      assert entry_type == "query_parameter"
    end)
  end

  test "PATCH /persons/:id", %{conn: conn} do
    merged_id1 = "cbe38ac6-a258-4b5d-b684-db53a4f54192"
    merged_id2 = "1190cd3a-18f0-4e0a-98d6-186cd6da145c"
    person = Factory.insert(:person, merged_ids: [merged_id1])

    patch conn, "/persons/#{person.id}", Poison.encode!(%{merged_ids: [merged_id2]})

    assert [^merged_id1, ^merged_id2] = MPI.Repo.get(MPI.Person, person.id).merged_ids
  end

  test "GET /persons/ SEARCH by last_name 200", %{conn: conn} do
    person = Factory.insert(:person, phones: nil)
    conn = get conn, person_path(conn, :index, [
      last_name: person.last_name,
      first_name: person.first_name,
      birth_date: to_string(person.birth_date)
    ])
    data = json_response(conn, 200)["data"]
    assert 1 == length(data)
    Enum.each(data, fn (person) ->
      refute Map.has_key?(person, "phone_number")
    end)
  end

  test "GET /all-persons SEARCH", %{conn: conn} do
    person = Factory.insert(:person, is_active: false)
    conn1 = get conn, person_path(conn, :all,
      last_name: person.last_name,
      second_name: person.second_name,
      first_name: person.first_name,
      birth_date: "1996-12-12",
    )
    data = json_response(conn1, 200)["data"]
    assert 1 == length(data)
    assert person.id == hd(data)["id"]

    conn2 = get conn, person_path(conn, :index,
      last_name: "last_name-0",
      second_name: "second_name-0",
      first_name: "first_name-0",
      birth_date: "1996-12-12",
    )
    data = json_response(conn2, 200)["data"]
    assert 0 == length(data)
  end

  test "GET /all-persons by ids", %{conn: conn} do
    %{id: id1} = Factory.insert(:person, is_active: false)
    %{id: id2} = Factory.insert(:person)
    Factory.insert(:person)
    conn1 = get conn, person_path(conn, :all,
      ids: Enum.join([id1, id2], ",")
    )
    data = json_response(conn1, 200)["data"]
    assert 2 == length(data)
    assert id1 == hd(data)["id"]
    assert id2 == Enum.at(data, 1)["id"]
  end

  test "GET /persons/ SEARCH by ids 200", %{conn: conn} do
    Factory.insert(:person)
    %{id: id_1} = Factory.insert(:person)
    %{id: id_2} = Factory.insert(:person)
    %{id: id_3} = Factory.insert(:person, %{is_active: false})
    %{id: id_4} = Factory.insert(:person, %{status: "INACTIVE"})
    %{id: id_5} = Factory.insert(:person, %{status: "MERGED"})

    ids = [id_1, id_2, id_3, id_4, id_5]

    conn = get conn, person_path(conn, :index, [ids: Enum.join(ids, ","), limit: 3])
    data = json_response(conn, 200)["data"]
    assert 2 == length(data)
    Enum.each(data, fn (person) ->
      assert person["id"] in [id_1, id_2]
      assert Map.has_key?(person, "first_name")
      assert Map.has_key?(person, "second_name")
      assert Map.has_key?(person, "last_name")
    end)
  end

  test "GET /persons/ empty search", %{conn: conn} do
    conn = get conn, person_path(conn, :index, [ids: ""])
    assert [] == json_response(conn, 200)["data"]
  end

  test "GET /persons/ SEARCH 200", %{conn: conn} do
    person =
      :person
      |> Factory.insert(%{
          phones: [
            Factory.build(:phone, %{type: "LANDLINE"}),
            Factory.build(:phone, %{type: "MOBILE"})
          ]
      })
      |> Map.put(:merged_ids, [])

    required_fields = ~W(id history first_name last_name birth_date birth_country birth_settlement merged_ids)
    # Getting mobile phone number because search uses just it
    phone_number =
      person
      |> Map.fetch!(:phones)
      |> Enum.filter(fn(phone) -> phone.type == "MOBILE" end)
      |> List.first
      |> Map.fetch!(:number)

    person_response =
      person
      |> Poison.encode!()
      |> Poison.decode!()
      |> Map.take(required_fields ++ ["second_name" , "tax_id"])
      |> Map.put("phone_number", phone_number)

    link = "/persons/?first_name=#{person.first_name}&last_name=#{person.last_name}&birth_date=#{person.birth_date}"
    res =
      conn
      |> get(link)
      |> json_response(200)

    assert_person_search(res["data"])
    person_first_response = Map.take(person_response, required_fields)
    assert [person_first_response] == res["data"]

    res =
      conn
      |> get("#{link}&second_name=#{String.upcase(person.second_name)}&tax_id=#{person.tax_id}")
      |> json_response(200)

    assert_person_search(res["data"])
    person_second_response = Map.take(person_response, required_fields ++ ["second_name" , "tax_id"])
    assert [person_second_response] == res["data"]

    phone_number = String.replace_prefix(phone_number, "+", "%2b")
    res =
      conn
      |> get("#{link}&phone_number=#{phone_number}")
      |> json_response(200)

    assert_person_search(res["data"])
    person_third_response = Map.take(person_response, required_fields ++ ["phone_number"])
    assert [person_third_response] == res["data"]

    res =
      conn
      |> get("#{link}&second_name=#{person.second_name}&tax_id=not_found")
      |> json_response(200)

    assert [] = res["data"]

    conn
    |> get("#{link}&phone_number=<>''''")
    |> json_response(422)
  end

  test "GET /persons/ SEARCH 403", %{conn: conn} do
    person = Factory.insert(:person)
    person_data = %{first_name: person.first_name, last_name: person.last_name, birth_date: person.birth_date}
    Factory.insert(:person, person_data)
    Factory.insert(:person, person_data)

    link = "/persons/?first_name=#{person.first_name}&last_name=#{person.last_name}&birth_date=#{person.birth_date}"

    error =
      conn
      |> get(link)
      |> json_response(403)
      |> Map.fetch!("error")

    assert %{
      "type" => "forbidden",
      "message" => "This API method returns only exact match results, " <>
                   "please retry with more specific search parameters"
    } = error
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
      "tax_id" => _,
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
    Enum.each(data, fn(person) ->
      assert %{
        "id" => _,
        "birth_date" => _,
      } = person
    end)
  end
end
