defmodule MPI.Web.PersonControllerTest do
  use MPI.Web.ConnCase
  alias MPI.Factory

  test "GET /persons/:id OK", %{conn: conn} do
    person = Factory.insert(:person)

    res =
      conn
      |> get("/persons/#{person.id}")
      |> json_response(200)

    assert res["data"]

    person =
      person
      |> Poison.encode!()
      |> Poison.decode!()
      |> Map.put("type", "person")
      |> Map.put("confident_persons", [])

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
    person_data = Factory.build_factory_params(:person)

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
    person_data = Factory.build_factory_params(:person)

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

  test "GET /persons/ SEARCH 200", %{conn: conn} do
    person = Factory.insert(:person,
      %{phones: [Factory.build(:phone, %{type: "LANDLINE"}), Factory.build(:phone, %{type: "MOBILE"})]}
    )

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
      |> Map.take(["birth_date", "history", "id", "first_name", "last_name", "second_name", "tax_id"])
      |> Map.put("phone_number", phone_number)

    link = "/persons/?first_name=#{person.first_name}&last_name=#{person.last_name}&birth_date=#{person.birth_date}"

    res =
      conn
      |> get(link)
      |> json_response(200)

    assert_person_search(res["data"])
    person_first_response =
      person_response
      |> Map.take(["first_name", "last_name", "birth_date", "history", "id"])

    assert [person_first_response] == res["data"]

    res =
      conn
      |> get("#{link}&second_name=#{person.second_name}&tax_id=#{person.tax_id}")
      |> json_response(200)

    assert_person_search(res["data"])
    person_second_response =
      person_response
      |> Map.take(["first_name", "last_name", "birth_date", "history", "id", "second_name", "tax_id"])
    assert [person_second_response] == res["data"]

    phone_number = String.replace_prefix(phone_number, "+", "%2b")
    res =
      conn
      |> get("#{link}&phone_number=#{phone_number}")
      |> json_response(200)

    assert_person_search(res["data"])
    person_third_response =
      person_response
      |> Map.take(["first_name", "last_name", "birth_date", "history", "id", "phone_number"])
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
      "message" => "This API method returns only exact match results, please retry with more specific search result"}
        = error
  end

  defp assert_person(data) do
    assert %{
      "id" => _,
      "first_name" => _,
      "last_name" => _,
      "second_name" => _,
      "email" => _,
      "gender" => _,
      "history" => [],
      "inserted_at" => _,
      "inserted_by" => _,
      "is_active" => true,
      "national_id" => _,
      "birth_date" => _,
      "death_date" => _,
      "tax_id" => _,
      "type" => "person",
      "updated_at" => _,
      "updated_by" => _,
      "signature" => _,
      "birth_place" => _,
      "addresses" => [
        %{
          "apartment" => _,
          "area" => _,
          "building" => _,
          "city" => _,
          "city_type" => _,
          "country" => _,
          "id" => _,
          "region" => _,
          "street" => _,
          "type" => _,
          "zip" => _
        }, _
      ],
      "documents" => [
        %{
          "expiration_date" => _,
          "id" => _,
          "issue_date" => _,
          "issued_by" => _,
          "number" => _,
          "type" => _
        }, _
      ],
      "phones" => [
        %{
          "id" => _,
          "number" => _,
          "type" => _
          }
      ],
      "confident_persons" => []
    } = data
  end

  def assert_person_search(data) do
    Enum.each(data, fn(person) ->
      assert %{
        "id" => _,
        "birth_date" => _,
        "history" => [],
      } = person
    end)
  end
end
