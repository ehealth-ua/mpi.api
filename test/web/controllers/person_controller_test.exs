defmodule MPI.Web.PersonControllerTest do
  @moduledoc false

  use MPI.Web.ConnCase
  import MPI.Factory
  import Mox
  alias MPI.{Repo, Persons.PersonsAPI}
  alias Ecto.UUID

  defp is_equal(key, person_key, attributes, data) do
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

  def json_person_attributes?(data) do
    is_equal("phones", :phones, ["number", "type"], data) && is_equal("documents", :documents, ["number", "type"], data)
  end

  test "successful show person", %{conn: conn} do
    person = insert(:person)

    res =
      conn
      |> get(person_path(conn, :show, person.id))
      |> json_response(200)

    assert res["data"]["id"] == person.id
    json_person_attributes?(res["data"])
    assert_person(res["data"])
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
    expect(KafkaMock, :publish_person_event, fn _, _ -> :ok end)

    person_data =
      build(:person)
      |> Poison.encode!()
      |> Poison.decode!()

    res =
      conn
      |> post(person_path(conn, :create), person_data)
      |> json_response(201)

    assert_person(res["data"])

    res =
      conn
      |> get(person_path(conn, :show, res["data"]["id"]))
      |> json_response(200)

    json_person_attributes?(res["data"])
    assert_person(res["data"])
  end

  test "successful create person with inserted_by, updayed_by by x-consumer-id", %{conn: conn} do
    expect(KafkaMock, :publish_person_event, fn _, _ -> :ok end)
    user_id = UUID.generate()

    person_data =
      build(:person)
      |> Poison.encode!()
      |> Poison.decode!()
      |> Map.delete("phones")

    res =
      conn
      |> put_req_header("x-consumer-id", user_id)
      |> post(person_path(conn, :create), person_data)
      |> json_response(201)

    assert_person(res["data"])
    assert res["data"]["inserted_by"] == user_id
    assert res["data"]["updated_by"] == user_id
  end

  test "successful create person without phones", %{conn: conn} do
    expect(KafkaMock, :publish_person_event, fn _, _ -> :ok end)

    person_data =
      build(:person)
      |> Poison.encode!()
      |> Poison.decode!()
      |> Map.delete("phones")

    res =
      conn
      |> post(person_path(conn, :create), person_data)
      |> json_response(201)

    assert_person(res["data"])

    res =
      conn
      |> get(person_path(conn, :show, res["data"]["id"]))
      |> json_response(200)

    json_person_attributes?(res["data"])
    assert_person(res["data"])
  end

  test "creation person without documents failed", %{conn: conn} do
    person_data =
      build(:person)
      |> Poison.encode!()
      |> Poison.decode!()
      |> Map.delete("documents")

    res =
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
           } = res["error"]
  end

  describe "create or update person with national id" do
    # TODO: cast national id according  to new rules in feature
    #   test "success create person and update national_id from documents if national_id is nil", %{conn: conn} do
    #     %{number: number} = document = build(:document, type: "NATIONAL_ID")
    #
    #     person_data =
    #       :person
    #       |> build(national_id: nil, documents: [document])
    #       |> Poison.encode!()
    #       |> Poison.decode!()
    #
    #     person_created =
    #       conn
    #       |> post(person_path(conn, :create), person_data)
    #       |> json_response(201)
    #
    #     assert number == person_created["data"]["national_id"]
    #     assert_person(person_created["data"])
    #   end

    # TODO: cast national id according  to new rules in feature
    # test "success update person and update national_id from documents if new national id is null", %{conn: conn} do
    #   %{number: number} = document = build(:document, type: "NATIONAL_ID")
    #   person = insert(:person, national_id: "old-national-id-number")
    #
    #   person_data =
    #     %{person | documents: [document], national_id: nil}
    #     |> Poison.encode!()
    #     |> Poison.decode!()
    #
    #   person_updated =
    #     conn
    #     |> post(person_path(conn, :create), person_data)
    #     |> json_response(200)
    #
    #   assert number == person_updated["data"]["national_id"]
    #   assert_person(person_updated["data"])
    # end

    test "success update person and update national_id ignore documents and check updated_by and inserted_by user", %{
      conn: conn
    } do
      inserted_by_id = UUID.generate()
      update_by_id = UUID.generate()
      document = build(:document, type: "NATIONAL_ID")
      person = insert(:person, national_id: "old-national-id-number", inserted_by: inserted_by_id)

      person_data =
        %{person | documents: [document], national_id: "new-national-id"}
        |> Poison.encode!()
        |> Poison.decode!()

      person_updated =
        conn
        |> put_req_header("x-consumer-id", update_by_id)
        |> post(person_path(conn, :create), person_data)
        |> json_response(200)

      assert "new-national-id" == person_updated["data"]["national_id"]
      assert_person(person_updated["data"])

      assert person_updated["data"]["inserted_by"] == inserted_by_id
      assert person_updated["data"]["updated_by"] == update_by_id
    end

    # TODO: cast national id according  to new rules in feature
    # test "success update person and national_id stau unchanged if national_id is nil in new enity and documents has no national id",
    #      %{conn: conn} do
    #   document = build(:document, type: "PASSPORT")
    #   person = insert(:person, national_id: "national-id")
    #
    #   person_data =
    #     %{person | documents: [document], national_id: nil}
    #     |> Poison.encode!()
    #     |> Poison.decode!()
    #
    #   person_updated =
    #     conn
    #     |> post(person_path(conn, :create), person_data)
    #     |> json_response(200)
    #
    #   assert person_updated["data"]["national_id"] == "national-id"
    #   assert_person(person_updated["data"])
    # end

    test "success update person documents without national_id do not change person's national_id", %{conn: conn} do
      document = build(:document, type: "PASSPORT")
      person = insert(:person, national_id: "national-id")

      person_data =
        %{person | documents: [document]}
        |> Poison.encode!()
        |> Poison.decode!()

      person_updated =
        conn
        |> post(person_path(conn, :create), person_data)
        |> json_response(200)

      assert "national-id" == person_updated["data"]["national_id"]
      assert_person(person_updated["data"])
    end
  end

  describe "create or update person" do
    test "success create and update person", %{conn: conn} do
      expect(KafkaMock, :publish_person_event, fn _, _ -> :ok end)

      person_data =
        :person
        |> build()
        |> Poison.encode!()
        |> Poison.decode!()
        |> Map.put("first_name", "test1")

      person_created =
        conn
        |> post(person_path(conn, :create), person_data)
        |> json_response(201)

      assert_person(person_created["data"])

      response =
        conn
        |> post(person_path(conn, :create), person_data)
        |> json_response(422)

      assert %{
               "error" => %{
                 "invalid" => [
                   %{
                     "entry" => "$.last_name",
                     "entry_type" => "json_data_property",
                     "rules" => [
                       %{
                         "description" => "has already been taken",
                         "params" => [],
                         "rule" => nil
                       }
                     ]
                   }
                 ]
               }
             } = response

      person_data =
        person_data
        |> Map.put("birth_country", "some-changed-birth-country")
        |> Map.put("phones", [
          %{"type" => "MOBILE", "number" => "+38#{Enum.random(1_000_000_000..9_999_999_999)}"}
        ])
        |> Map.put("id", person_created["data"]["id"])

      res =
        conn
        |> post(person_path(conn, :create), person_data)
        |> json_response(200)

      assert_person(res["data"])

      res =
        conn
        |> get(person_path(conn, :show, person_created["data"]["id"]))
        |> json_response(200)

      assert res["data"]
      json_person_attributes?(res["data"])
      assert res["data"]["birth_country"] == "some-changed-birth-country"
    end

    test "person not found", %{conn: conn} do
      assert conn
             |> post(person_path(conn, :create), %{"id" => Ecto.UUID.generate()})
             |> json_response(404)
    end

    test "person is not active", %{conn: conn} do
      person = insert(:person, is_active: false)

      assert conn
             |> post(person_path(conn, :create), %{"id" => person.id})
             |> json_response(409)
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
      |> head("/persons/#{UUID.generate()}")
      |> Map.fetch!(:status)

    assert status == 404
  end

  test "successful update person", %{conn: conn} do
    person = insert(:person)

    person_data =
      :person
      |> build()
      |> Poison.encode!()
      |> Poison.decode!()

    res =
      conn
      |> put(person_path(conn, :update, person.id), person_data)
      |> json_response(200)

    assert res["data"]
    json_person_attributes?(res["data"])
    assert_person(res["data"])
  end

  describe "reset auth method" do
    test "success", %{conn: conn} do
      person = insert(:person)

      res =
        conn
        |> patch(person_path(conn, :reset_auth_method, person.id))
        |> json_response(200)

      assert res["data"]
      assert_person(res["data"])
      assert [%{"type" => "NA"}] == res["data"]["authentication_methods"]
    end

    test "invalid status", %{conn: conn} do
      person = insert(:person, status: "INACTIVE")

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

  test "successful update person with merged_ids", %{conn: conn} do
    merged_id1 = UUID.generate()
    merged_id2 = UUID.generate()
    person = insert(:person, merged_ids: [merged_id1])

    patch(conn, person_path(conn, :update, person.id), Poison.encode!(%{merged_ids: [merged_id2]}))

    assert [^merged_id1, ^merged_id2] = Repo.get(MPI.Person, person.id).merged_ids
  end

  test "successful persons search by last_name", %{conn: conn} do
    person = insert(:person, phones: [])

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
    person = insert(:person)
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

  test "successful persons search by ids", %{conn: conn} do
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

  test "empty search", %{conn: conn} do
    conn = get(conn, person_path(conn, :index, ids: ""))
    assert [] == json_response(conn, 200)["data"]
  end

  test "successful person search", %{conn: conn} do
    person =
      insert(
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
end
