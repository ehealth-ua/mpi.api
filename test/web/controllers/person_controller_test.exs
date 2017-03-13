defmodule Mpi.Web.PersonControllerTest do
  use Mpi.Web.ConnCase

  test "GET /persons/:id OK", %{conn: conn} do
    person = MPI.Factory.insert(:person)

    res = conn
    |> get("/persons/#{person.id}")
    |> json_response(200)

    assert res["data"]

    person =
      person
      |> Poison.encode!()
      |> Poison.decode!()
      |> Map.put("type", "person")

    assert person == res["data"]


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
      ]
     } = res["data"]
  end

  test "GET /persons/not_found", %{conn: conn} do
    response = conn
    |> get("/persons/9fa323da-37e1-4789-87f1-8776999d5196")
    |> json_response(404)
    |> Map.fetch!("error")

    assert response == %{"type" => "not_found"}
  end
end
