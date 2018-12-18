defmodule Deduplication.V2.MatchTest do
  @moduledoc false

  use Core.ModelCase, async: false
  import Ecto.Query
  import Core.Factory
  import Mox

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.PersonAddress
  alias Core.PersonDocument
  alias Core.Repo
  alias Deduplication.V2.Match
  alias Deduplication.Worker

  setup :verify_on_exit!
  setup :set_mox_global

  setup do
    stub(DeduplicationWorkerMock, :run_deduplication, fn -> :ok end)
    stub(DeduplicationWorkerMock, :stop_application, fn -> :ok end)
    {:ok, _pid} = Worker.start_link()
    :ok
  end

  def candidate_count(n), do: candidate_count(n, 0)

  def candidate_count(1, acc), do: acc

  def candidate_count(n, acc) do
    candidate_count(n - 1, n - 1 + acc)
  end

  describe "tests kafka send" do
    test "no match merge" do
      expect(PyWeightMock, :weight, fn %{} -> 0.5 end)

      Enum.each(0..1, fn i ->
        insert(:person, tax_id: "123456789", first_name: "#{i}")
      end)

      assert 2 = Match.deduplicate_person(100, 0)

      assert [] =
               MergeCandidate
               |> Repo.all()
    end

    test "no automated merge" do
      expect(PyWeightMock, :weight, fn %{} -> 0.8 end)

      Enum.each(0..1, fn i ->
        insert(:person, tax_id: "123456789", first_name: "#{i}")
      end)

      assert 2 = Match.deduplicate_person(100, 0)

      assert [_m] =
               MergeCandidate
               |> Repo.all()
    end

    test "automated merge" do
      expect(PyWeightMock, :weight, fn %{} -> 0.9 end)
      expect(DeduplicationKafkaMock, :publish_person_merged_event, fn _, _ -> :ok end)

      Enum.each(0..1, fn i ->
        insert(:person, tax_id: "123456789", first_name: "#{i}")
      end)

      assert 2 = Match.deduplicate_person(100, 0)

      assert [_m] =
               MergeCandidate
               |> Repo.all()
    end
  end

  describe "test :run" do
    setup do
      stub(DeduplicationKafkaMock, :publish_person_merged_event, fn _, _ -> :ok end)
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      :ok
    end

    @tag :pending
    test "for completed db works" do
      pid = self()

      expect(DeduplicationWorkerMock, :stop_application, fn ->
        send(pid, :mock_done)
        :ok
      end)

      Enum.map(1..300, fn _ -> insert(:person, merge_verified: true) end)
      send(Worker, :run)
      assert_receive :mock_done, 1000
    end

    @tag :pending
    test "for random persons works" do
      pid = self()

      expect(DeduplicationWorkerMock, :stop_application, fn ->
        send(pid, :mock_done)
        :ok
      end)

      Enum.map(1..100, fn _ -> insert(:person) end)
      send(Worker, :run)
      assert_receive :mock_done, 5000
    end

    @tag :pending
    test "for existing unverified persons works" do
      pid = self()

      expect(DeduplicationWorkerMock, :stop_application, fn ->
        send(pid, :mock_done)
        :ok
      end)

      n1 = 100
      n2 = 100

      Enum.each(1..n1, fn i ->
        insert(:person,
          tax_id: "123456789",
          first_name: "#{i}",
          documents: [build(:document, number: "#{i}")],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")]
        )
      end)

      Enum.each(1..n2, fn i ->
        insert(:person,
          tax_id: "000000000",
          first_name: "#{i}",
          documents: [build(:document, number: "999#{i}")],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")]
        )
      end)

      send(Worker, :run)
      assert_receive :mock_done, 20_000

      merge_candidates_number =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()
        |> Enum.map(fn %MergeCandidate{master_person: mp, person: p} ->
          assert mp.tax_id == p.tax_id
        end)
        |> Enum.count()

      assert candidate_count(n1) + candidate_count(n2) == merge_candidates_number
    end
  end

  describe "test deduplicate_person/0 by tax_id + auth phone + documents" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      stub(DeduplicationKafkaMock, :publish_person_merged_event, fn _, _ -> :ok end)
      :ok
    end

    test "only matched persons" do
      person_ids =
        Enum.map(1..5, fn _i ->
          p =
            insert(:person,
              tax_id: "123456789",
              documents: [build(:document, number: "000123")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+380630000000"
                )
              ]
            )

          p.id
        end)

      assert 5 = Match.deduplicate_person(100, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) == Enum.count(candidates)

      Enum.each(candidates, fn c ->
        assert c.person_id in person_ids
        assert c.master_person_id in person_ids
        assert c.person.id in c.master_person.merged_ids
      end)
    end

    test "matched persons by all fields with rest" do
      person_ids =
        Enum.map(1..5, fn _i ->
          p =
            insert(:person,
              tax_id: "123456789",
              documents: [build(:document, number: "000123")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+380630000000"
                )
              ]
            )

          p.id
        end)

      Enum.each(1..5, fn i ->
        p =
          insert(:person,
            tax_id: "#{i}",
            documents: [build(:document, number: "#{i}")],
            authentication_methods: [
              build(:authentication_method,
                type: "OTP",
                phone_number: "+3806300000#{i}"
              )
            ]
          )

        p.id
      end)

      assert 10 = Match.deduplicate_person(100, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) == Enum.count(candidates)

      Enum.each(candidates, fn c ->
        assert c.person_id in person_ids
        assert c.master_person_id in person_ids
        assert c.person.id in c.master_person.merged_ids
      end)
    end
  end

  describe "auth phone number + document number only" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      stub(DeduplicationKafkaMock, :publish_person_merged_event, fn _, _ -> :ok end)
      :ok
    end

    test "test deduplicate_person/0 document number + auth phone number " do
      t_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:person,
              tax_id: "000#{i}",
              documents: [build(:document, number: "0000")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+380630000000"
                )
              ]
            )

          p.id
        end)

      a_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:person,
              tax_id: "#{i}",
              documents: [build(:document, number: "0000")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+38063000000#{i}"
                )
              ]
            )

          p.id
        end)

      Enum.each(1..3, fn i ->
        insert(:person,
          tax_id: "#{i * 100}",
          documents: [build(:document, number: "111#{i}")],
          authentication_methods: [
            build(:authentication_method,
              type: "OTP",
              phone_number: "+38093111111#{i}"
            )
          ]
        )
      end)

      assert 13 = Match.deduplicate_person(100, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(10) == Enum.count(candidates)
      matched_persons = t_person_ids ++ a_person_ids

      Enum.each(candidates, fn c ->
        assert c.person_id in matched_persons
        assert c.master_person_id in matched_persons
        assert c.person.id in c.master_person.merged_ids
      end)
    end
  end

  describe "test deduplicate_person/0 by tax_id + auth documents only" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      stub(DeduplicationKafkaMock, :publish_person_merged_event, fn _, _ -> :ok end)
      :ok
    end

    test "document numbers only" do
      person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:person,
              tax_id: "#{i}",
              documents: [build(:document, number: "0000")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+38063000000#{i}"
                )
              ]
            )

          p.id
        end)

      Enum.each(1..5, fn i ->
        insert(:person,
          tax_id: "#{i * 10}",
          documents: [build(:document, number: "999#{i}")],
          authentication_methods: [
            build(:authentication_method,
              type: "OTP",
              phone_number: "#{i}"
            )
          ]
        )
      end)

      assert 10 = Match.deduplicate_person(100, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) == Enum.count(candidates)

      Enum.each(candidates, fn c ->
        assert c.person_id in person_ids
        assert c.master_person_id in person_ids
        assert c.person.id in c.master_person.merged_ids
      end)
    end

    test "test deduplicate_person/0 document number + tax_id" do
      t_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:person,
              tax_id: "#{i}",
              documents: [build(:document, number: "0000")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+38063000000#{i}"
                )
              ]
            )

          p.id
        end)

      a_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:person,
              tax_id: "#{i}",
              documents: [build(:document, number: "0000")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+38063000000#{i}"
                )
              ]
            )

          p.id
        end)

      Enum.each(1..3, fn i ->
        insert(:person,
          tax_id: "#{i * 100}",
          documents: [build(:document, number: "111#{i}")],
          authentication_methods: [
            build(:authentication_method,
              type: "OTP",
              phone_number: "+38093111111#{i}"
            )
          ]
        )
      end)

      assert 13 = Match.deduplicate_person(100, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(10) == Enum.count(candidates)

      matched_persons = t_person_ids ++ a_person_ids

      Enum.each(candidates, fn c ->
        assert c.person_id in matched_persons
        assert c.master_person_id in matched_persons
        assert c.person.id in c.master_person.merged_ids
      end)
    end
  end

  describe "test deduplicate_person/0 by tax_id + auth phone only" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      stub(DeduplicationKafkaMock, :publish_person_merged_event, fn _, _ -> :ok end)
      :ok
    end

    test "auth phone only" do
      person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:person,
              tax_id: "#{i}",
              documents: [build(:document, number: "#{i}")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+380630000000"
                )
              ]
            )

          p.id
        end)

      Enum.each(1..5, fn i ->
        insert(:person,
          tax_id: "#{i * 10}",
          documents: [build(:document, number: "999#{i}")],
          authentication_methods: [
            build(:authentication_method,
              type: "OTP",
              phone_number: "#{i}"
            )
          ]
        )
      end)

      assert 10 = Match.deduplicate_person(100, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) == Enum.count(candidates)

      Enum.each(candidates, fn c ->
        assert c.person_id in person_ids
        assert c.master_person_id in person_ids
        assert c.person.id in c.master_person.merged_ids
      end)
    end

    test "test deduplicate_person/0 auth phone + tax_id" do
      t_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:person,
              tax_id: "#{i}",
              documents: [build(:document, number: "#{i}")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+380630000000"
                )
              ]
            )

          p.id
        end)

      a_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:person,
              tax_id: "#{i}",
              documents: [build(:document, number: "000#{i}")],
              authentication_methods: [
                build(:authentication_method,
                  type: "OTP",
                  phone_number: "+380630000000"
                )
              ]
            )

          p.id
        end)

      Enum.each(1..3, fn i ->
        insert(:person,
          tax_id: "#{i * 100}",
          documents: [build(:document, number: "111#{i}")],
          authentication_methods: [
            build(:authentication_method,
              type: "OTP",
              phone_number: "+38093111111#{i}"
            )
          ]
        )
      end)

      assert 13 = Match.deduplicate_person(100, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(10) == Enum.count(candidates)
      matched_persons = t_person_ids ++ a_person_ids

      Enum.each(candidates, fn c ->
        assert c.person_id in matched_persons
        assert c.master_person_id in matched_persons
        assert c.person.id in c.master_person.merged_ids
      end)
    end
  end

  describe "test deduplicate_person/0 by tax_id only" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      stub(DeduplicationKafkaMock, :publish_person_merged_event, fn _, _ -> :ok end)
      :ok
    end

    test "no persons" do
      assert 0 == Match.deduplicate_person(10, 0)
      insert(:person, merge_verified: true)
      assert 0 == Match.deduplicate_person(1, 0)
    end

    test "one person no duplicates" do
      insert(:person, tax_id: "0987654321")
      insert(:person, tax_id: "0987654321")
      assert 1 = Match.deduplicate_person(1, 1)
    end

    test "duplicates persons with rest persons" do
      Enum.each(1..1, fn i ->
        insert(:person,
          tax_id: "#{i}",
          documents: [build(:document, number: "999#{i}")],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")]
        )
      end)

      Enum.each(1..3, fn i ->
        insert(:person,
          tax_id: "123456789",
          first_name: "#{i}",
          documents: [
            build(:document, number: "#{i}")
          ],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")]
        )
      end)

      assert 4 = Match.deduplicate_person(100, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(3) == Enum.count(candidates)

      Enum.each(candidates, fn c ->
        assert c.person.tax_id == "123456789"
        assert c.master_person.tax_id == "123456789"
      end)
    end

    test "duplicates persons only" do
      Enum.each(1..10, fn i ->
        insert(:person,
          tax_id: "123456789",
          first_name: "#{i}",
          documents: [build(:document, number: "#{i}")],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")]
        )
      end)

      assert 10 = Match.deduplicate_person(10, 0)
      assert 0 = Match.deduplicate_person(1, 0)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      Enum.each(candidates, fn c ->
        assert c.person.tax_id == "123456789"
        assert c.master_person.tax_id == "123456789"
      end)

      active_person =
        Person
        |> where([p], p.tax_id == "123456789")
        |> order_by([p], desc: p.inserted_at)
        |> limit(1)
        |> Repo.one()

      assert "active" == active_person.status
      assert candidate_count(10) == Enum.count(candidates)
    end
  end

  describe "match_candidates" do
    setup do
      expect(DeduplicationKafkaMock, :publish_person_merged_event, fn _, _ -> :ok end)
      :ok
    end

    test "with actual data results in correct woes case 1" do
      expect(PyWeightMock, :weight, fn woes ->
        assert %{
                 authentication_methods_flag_woe: -0.962223178,
                 birth_settlement_substr_woe: -1.033368721,
                 candidate_id: "ebf38e27-7eda-48cd-8639-5b9ca66f9fe8",
                 d_documents_woe: -2.12133861,
                 d_first_name_woe: -1.379763317,
                 d_last_name_woe: -1.181889463,
                 d_second_name_woe: -1.405398133,
                 d_tax_id_woe: -2.714837812,
                 docs_same_number_woe: -2.065190805,
                 gender_flag_woe: -0.43537168,
                 person_id: "4b889b15-b4c9-4cf1-9cb7-2bbc245d676d",
                 registration_address_settlement_flag_woe: -0.937089181,
                 residence_settlement_flag_woe: -0.906624219,
                 twins_flag_woe: -0.159950822
               } == woes

        1
      end)

      person1 =
        create_person(
          "4b889b15-b4c9-4cf1-9cb7-2bbc245d676d",
          " Богдана",
          "Проценко",
          "Олександрівна",
          "FEMALE",
          "1234567890",
          "1/1/91",
          "Україна",
          "PASSPORT",
          "CM 93333332",
          "BIRTH_CERTIFICATE",
          "CM 93333332",
          "БІЛА ЦЕРКВА",
          "БІЛА ЦЕРКВА",
          "380671111111"
        )

      person2 =
        create_person(
          "ebf38e27-7eda-48cd-8639-5b9ca66f9fe8",
          "Богданна",
          "Проценко",
          "Олександрівна",
          "FEMALE",
          "1234567890",
          "1/2/91",
          "Україна",
          "PASSPORT",
          "CM 93333332",
          "BIRTH_CERTIFICATE",
          "CM 93444332",
          "БІЛА ЦЕРКВА",
          "БІЛА ЦЕРКВА",
          "380671111111"
        )

      [res] = Match.match_candidates([person2], person1)
      assert 1 == Map.get(res, :weight)
    end

    test "with actual data results in correct woes case 2" do
      expect(PyWeightMock, :weight, fn woes ->
        assert %{
                 authentication_methods_flag_woe: -0.962223178,
                 birth_settlement_substr_woe: -1.033368721,
                 candidate_id: "04ca5d87-1918-4f3c-be29-606adf8dd53c",
                 d_documents_woe: -2.12133861,
                 d_first_name_woe: -2.801009159,
                 d_last_name_woe: -1.181889463,
                 d_second_name_woe: -1.405398133,
                 d_tax_id_woe: -2.714837812,
                 docs_same_number_woe: -2.065190805,
                 gender_flag_woe: -0.43537168,
                 person_id: "ebf38e27-7eda-48cd-8639-5b9ca66f9fe8",
                 registration_address_settlement_flag_woe: -0.937089181,
                 residence_settlement_flag_woe: -0.906624219,
                 twins_flag_woe: -0.159950822
               } == woes

        1
      end)

      person1 =
        create_person(
          "ebf38e27-7eda-48cd-8639-5b9ca66f9fe8",
          " Анна Марі''я",
          "коноваленко-коноваленко",
          "мирославівна",
          "FEMALE",
          "1234567890",
          "1991-01-08",
          "Україна",
          "PASSPORT",
          "CM 123456",
          "BIRTH_CERTIFICATE",
          "1СМ 93333332",
          "БІЛА ЦЕРКВА",
          "БІЛА ЦЕРКВА",
          "+380671111111"
        )

      person2 =
        create_person(
          "04ca5d87-1918-4f3c-be29-606adf8dd53c",
          "анна - мария ",
          "Коноваленко Коноваленко ",
          "Мірославовна",
          "FEMALE",
          "1234567890",
          "1991-01-08",
          "   країна Україна",
          "PASSPORT",
          "CM 654321",
          "BIRTH_CERTIFICATE",
          "ІСМ 93333332",
          "БІЛА ЦЕРКВА",
          "БІЛА ЦЕРКВА",
          "+380671111111"
        )

      [res] = Match.match_candidates([person2], person1)
      assert 1 == Map.get(res, :weight)
    end

    test "with actual data results in correct woes case 3" do
      expect(PyWeightMock, :weight, fn woes ->
        assert %{
                 authentication_methods_flag_woe: 1.242406002,
                 birth_settlement_substr_woe: -1.033368721,
                 candidate_id: "5268b461-075e-4fc1-8efe-1fc73a4d00c0",
                 d_documents_woe: 0.907611604,
                 d_first_name_woe: -2.801009159,
                 d_last_name_woe: 3.421035127,
                 d_second_name_woe: -0.988391454,
                 d_tax_id_woe: -0.217612736,
                 docs_same_number_woe: 1.485675379,
                 gender_flag_woe: 2.886330559,
                 person_id: "eaa1e6cd-e6ad-4eef-8962-a15e702249e4",
                 registration_address_settlement_flag_woe: 2.456584084,
                 residence_settlement_flag_woe: 2.312877566,
                 twins_flag_woe: -0.159950822
               } == woes

        1
      end)

      person1 =
        create_person(
          "eaa1e6cd-e6ad-4eef-8962-a15e702249e4",
          "Максим",
          "кононенко",
          "олександрович",
          "MALE",
          "1234567890",
          "2010-01-08",
          "cелище Шарки",
          nil,
          nil,
          "BIRTH_CERTIFICATE",
          "СМ-С",
          "БІЛА ЦЕРКВА",
          "БІЛА ЦЕРКВА",
          "+380671111111"
        )

      person2 =
        create_person(
          "5268b461-075e-4fc1-8efe-1fc73a4d00c0",
          "максім",
          "кононенко Коноваленко ",
          nil,
          "FEMALE",
          nil,
          "2013-01-08",
          "Шарки",
          nil,
          nil,
          "BIRTH_CERTIFICATE",
          "СMC",
          "ГАДЯЧ",
          "ГАДЯЧ",
          nil
        )

      [res] = Match.match_candidates([person2], person1)
      assert 1 == Map.get(res, :weight)
    end
  end

  defp create_person(
         id,
         first_name,
         last_name,
         second_name,
         gender,
         tax_id,
         birth_date,
         birth_settlement,
         document_type1,
         number1,
         document_type2,
         number2,
         residence_address_settlement,
         registration_address_settlement,
         authentication_number
       ) do
    %Person{
      id: id,
      first_name: first_name,
      last_name: last_name,
      second_name: second_name,
      birth_date: birth_date,
      birth_settlement: birth_settlement,
      gender: gender,
      tax_id: tax_id,
      is_active: true,
      documents: [
        create_person_document(document_type1, number1),
        create_person_document(document_type2, number2)
      ],
      addresses: [
        create_address("RESIDENCE", residence_address_settlement),
        create_address("REGISTRATION", registration_address_settlement)
      ],
      authentication_methods: [create_authentication_methods(authentication_number)]
    }
  end

  defp create_person_document(document_type, number) do
    %PersonDocument{
      type: document_type,
      number: number
    }
  end

  defp create_address(type, settlement) when type in ["RESIDENCE", "REGISTRATION"] do
    %PersonAddress{
      type: type,
      country: "UA",
      settlement: settlement,
      settlement_type: "CITY"
    }
  end

  defp create_authentication_methods(phone_number) do
    %{
      "type" => "OTP",
      "phone_number" => phone_number
    }
  end
end
