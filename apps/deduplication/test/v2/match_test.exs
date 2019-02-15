defmodule Deduplication.V2.MatchTest do
  @moduledoc false

  use Core.ModelCase, async: false
  use Confex, otp_app: :deduplication
  import Ecto.Query
  import Core.Factory
  import Mox

  alias Core.ManualMergeCandidate
  alias Core.MergeCandidate
  alias Core.Person
  alias Core.PersonAddress
  alias Core.PersonDocument
  alias Core.Repo
  alias Core.DeduplicationRepo
  alias Deduplication.V2.Match
  alias Deduplication.V2.Model
  alias Ecto.UUID

  setup :verify_on_exit!
  setup :set_mox_global

  def candidate_count(n), do: candidate_count(n, 0)

  def candidate_count(1, acc), do: acc

  def candidate_count(n, acc) do
    candidate_count(n - 1, n - 1 + acc)
  end

  describe "retrieve_candidates" do
    setup do
      Model.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "number of candidates > candidates_batch_size  works" do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)

      batch_size = Confex.fetch_env!(:deduplication, Deduplication.V2.Model)[:candidates_batch_size]

      n = batch_size * 5

      Enum.map(1..n, fn _ ->
        insert(:mpi, :person, tax_id: "000000000")
      end)

      persons = Model.get_unverified_persons(n)
      assert n == Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      merge_candidates_number =
        MergeCandidate
        |> Repo.all()
        |> Enum.count()

      assert candidate_count(n) == merge_candidates_number
    end
  end

  describe "test Match.deduplicate_persons by tax_id + auth phone + documents" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      Model.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "only matched persons" do
      person_ids =
        5
        |> insert_list(:mpi, :person,
          tax_id: "123456789",
          documents: [build(:document, number: "000123")],
          authentication_methods: [
            build(:authentication_method,
              type: "OTP",
              phone_number: "+380630000000"
            )
          ]
        )
        |> Enum.map(& &1.id)

      persons = Model.get_unverified_persons(5)
      assert 5 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(13)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) == Enum.count(candidates)

      Enum.each(candidates, fn candidate ->
        assert candidate.person_id in person_ids
        assert candidate.master_person_id in person_ids
      end)
    end

    test "matched persons by all fields with rest" do
      person_ids =
        5
        |> insert_list(:mpi, :person,
          tax_id: "123456789",
          documents: [build(:document, number: "000123")],
          authentication_methods: [
            build(:authentication_method,
              type: "OTP",
              phone_number: "+380630000000"
            )
          ]
        )
        |> Enum.map(& &1.id)

      Enum.each(1..5, fn i ->
        p =
          insert(:mpi, :person,
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

      persons = Model.get_unverified_persons(10)
      assert 10 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(13)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) == Enum.count(candidates)

      Enum.each(candidates, fn candidate ->
        assert candidate.person_id in person_ids
        assert candidate.master_person_id in person_ids
      end)
    end
  end

  describe "persons deduplication creates manual merge candidates" do
    setup do
      Model.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "only matched persons" do
      expect(PyWeightMock, :weight, 3, fn %{} -> 0.85 end)
      stub(PyWeightMock, :weight, fn %{} -> 0.95 end)

      person_ids =
        5
        |> insert_list(:mpi, :person,
          tax_id: "123456789",
          documents: [build(:document, number: "000123")],
          authentication_methods: [
            build(:authentication_method,
              type: "OTP",
              phone_number: "+380630000000"
            )
          ]
        )
        |> Enum.map(& &1.id)

      persons = Model.get_unverified_persons(5)
      assert 5 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(13)

      candidates = DeduplicationRepo.all(ManualMergeCandidate)

      assert 3 == Enum.count(candidates)

      Enum.each(candidates, fn candidate ->
        assert candidate.person_id in person_ids
        assert candidate.master_person_id in person_ids
      end)
    end
  end

  describe "auth phone number + document number only" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      Model.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "test Worker.deduplicate/0 document number + auth phone number " do
      t_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:mpi, :person,
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
            insert(:mpi, :person,
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
        insert(:mpi, :person,
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

      persons = Model.get_unverified_persons(13)
      assert 13 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(10) == Enum.count(candidates)
      matched_persons = t_person_ids ++ a_person_ids

      Enum.each(candidates, fn candidate ->
        assert candidate.person_id in matched_persons
        assert candidate.master_person_id in matched_persons
      end)
    end
  end

  describe "test Worker.deduplicate/0 by tax_id + auth documents only" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      Model.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "document numbers only" do
      person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:mpi, :person,
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
        insert(:mpi, :person,
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

      persons = Model.get_unverified_persons(10)
      assert 10 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) == Enum.count(candidates)

      Enum.each(candidates, fn candidate ->
        assert candidate.person_id in person_ids
        assert candidate.master_person_id in person_ids
      end)
    end

    test "test Worker.deduplicate/0 document number + tax_id" do
      t_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:mpi, :person,
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
            insert(:mpi, :person,
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
        insert(:mpi, :person,
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

      persons = Model.get_unverified_persons(13)
      assert 13 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(13)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(10) == Enum.count(candidates)

      matched_persons = t_person_ids ++ a_person_ids

      Enum.each(candidates, fn candidate ->
        assert candidate.person_id in matched_persons
        assert candidate.master_person_id in matched_persons
      end)
    end
  end

  describe "test Worker.deduplicate/0 by tax_id + auth phone only" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      Model.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "auth phone only" do
      person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:mpi, :person,
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
        insert(:mpi, :person,
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

      persons = Model.get_unverified_persons(10)
      assert 10 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) == Enum.count(candidates)

      Enum.each(candidates, fn candidate ->
        assert candidate.person_id in person_ids
        assert candidate.master_person_id in person_ids
      end)
    end

    test "test Worker.deduplicate/0 auth phone + tax_id" do
      t_person_ids =
        Enum.map(1..5, fn i ->
          p =
            insert(:mpi, :person,
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
            insert(:mpi, :person,
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
        insert(:mpi, :person,
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

      persons = Model.get_unverified_persons(13)
      assert 13 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(10) == Enum.count(candidates)
      matched_persons = t_person_ids ++ a_person_ids

      Enum.each(candidates, fn candidate ->
        assert candidate.person_id in matched_persons
        assert candidate.master_person_id in matched_persons
      end)
    end
  end

  describe "test Worker.deduplicate/0 by tax_id only" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      Model.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "no persons" do
      persons = Model.get_unverified_persons(0)
      assert 0 = Match.deduplicate_persons(persons)
      insert(:mpi, :person)
      Model.set_current_verified_ts(DateTime.utc_now())
      persons = Model.get_unverified_persons(0)
      assert 0 = Match.deduplicate_persons(persons)
    end

    test "one person one duplicates" do
      stale = insert(:mpi, :person, tax_id: "0987654321", first_name: "Stale")
      actual = insert(:mpi, :person, tax_id: "0987654321", first_name: "Actual")
      persons = Model.get_unverified_persons(2)
      assert 2 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      assert [%MergeCandidate{master_person_id: actual_id, person_id: stale_id}] = Repo.all(MergeCandidate)

      assert stale_id == stale.id
      assert actual_id == actual.id
    end

    test "duplicates persons with rest persons" do
      Enum.each(1..1, fn i ->
        insert(:mpi, :person,
          tax_id: "#{i}",
          documents: [build(:document, number: "999#{i}")],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")]
        )
      end)

      Enum.each(1..3, fn i ->
        insert(:mpi, :person,
          tax_id: "123456789",
          first_name: "#{i}",
          documents: [
            build(:document, number: "#{i}")
          ],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")]
        )
      end)

      persons = Model.get_unverified_persons(10)
      assert 4 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(3) == Enum.count(candidates)

      Enum.each(candidates, fn candidate ->
        assert candidate.person.tax_id == "123456789"
        assert candidate.master_person.tax_id == "123456789"
      end)
    end

    test "duplicates persons only" do
      Enum.each(1..10, fn i ->
        insert(:mpi, :person,
          tax_id: "123456789",
          first_name: "#{i}",
          documents: [build(:document, number: "#{i}")],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")]
        )
      end)

      persons = Model.get_unverified_persons(10)
      assert 10 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(10)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      Enum.each(candidates, fn candidate ->
        assert candidate.person.tax_id == "123456789"
        assert candidate.master_person.tax_id == "123456789"
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

  describe "settlement_id" do
    setup do
      stub(PyWeightMock, :weight, fn %{} -> 1 end)
      Model.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "settlement_id + first name with rest persons" do
      settlement_id = UUID.generate()

      Enum.each(1..3, fn i ->
        insert(:mpi, :person,
          tax_id: "#{i}",
          first_name: "Iv",
          documents: [build(:document, number: "999#{i}")],
          person_addresses: [
            build(:person_address,
              settlement_id: settlement_id,
              person_first_name: "Iv"
            )
          ]
        )
      end)

      Enum.each(1..3, fn i ->
        insert(:mpi, :person,
          tax_id: "#{i / 100}",
          documents: [
            build(:document, number: "#{i}")
          ],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")],
          person_addresses: [build(:person_address, settlement_id: UUID.generate())]
        )
      end)

      persons = Model.get_unverified_persons(10)
      assert 6 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(3) == Enum.count(candidates)
    end

    test "settlement_id + last_name with tax_id" do
      settlement_id = UUID.generate()

      Enum.each(1..5, fn i ->
        insert(:mpi, :person,
          tax_id: "#{i}",
          last_name: "Kusto",
          documents: [build(:document, number: "999#{i}")],
          person_addresses: [
            build(:person_address,
              settlement_id: settlement_id,
              person_last_name: "Kusto"
            )
          ]
        )
      end)

      another_settlement_id = UUID.generate()

      insert(:mpi, :person,
        tax_id: "#{3}",
        documents: [build(:document, number: "0000")],
        person_addresses: [build(:person_address, settlement_id: another_settlement_id)]
      )

      Enum.each(1..3, fn i ->
        insert(:mpi, :person,
          tax_id: "00000#{i}",
          documents: [build(:document, number: "#{i}")],
          authentication_methods: [build(:authentication_method, type: "OFFLINE")],
          person_addresses: [build(:person_address, settlement_id: UUID.generate())]
        )
      end)

      persons = Model.get_unverified_persons(10)
      assert 9 = Match.deduplicate_persons(persons)
      assert [] == Model.get_unverified_persons(1)

      candidates =
        MergeCandidate
        |> preload([:master_person, :person])
        |> Repo.all()

      assert candidate_count(5) + 1 == Enum.count(candidates)
    end
  end

  describe "match_candidates" do
    test "with actual data results in correct woes case 1" do
      expect(PyWeightMock, :weight, fn bins ->
        assert %{
                 authentication_methods_flag_bin: 0,
                 birth_settlement_substr_bin: 0,
                 candidate_id: "ebf38e27-7eda-48cd-8639-5b9ca66f9fe8",
                 d_documents_bin: "0x>6",
                 d_first_name_bin: 0,
                 d_last_name_bin: 1,
                 d_second_name_bin: 1,
                 d_tax_id_bin: 0,
                 docs_same_number_bin: "0x3",
                 gender_flag_bin: 0,
                 person_id: "4b889b15-b4c9-4cf1-9cb7-2bbc245d676d",
                 residence_settlement_flag_bin: 0,
                 twins_flag_bin: 0
               } == bins

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
      expect(PyWeightMock, :weight, fn bins ->
        assert %{
                 authentication_methods_flag_bin: 0,
                 birth_settlement_substr_bin: 0,
                 candidate_id: "04ca5d87-1918-4f3c-be29-606adf8dd53c",
                 d_documents_bin: "0x<6",
                 d_first_name_bin: 0,
                 d_last_name_bin: 1,
                 d_second_name_bin: 1,
                 d_tax_id_bin: 0,
                 docs_same_number_bin: "0x3",
                 gender_flag_bin: 0,
                 person_id: "ebf38e27-7eda-48cd-8639-5b9ca66f9fe8",
                 residence_settlement_flag_bin: 0,
                 twins_flag_bin: 0
               } == bins

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
      expect(PyWeightMock, :weight, fn bins ->
        assert %{
                 authentication_methods_flag_bin: 1,
                 birth_settlement_substr_bin: 0,
                 candidate_id: "5268b461-075e-4fc1-8efe-1fc73a4d00c0",
                 d_documents_bin: "2",
                 d_first_name_bin: 0,
                 d_last_name_bin: 4,
                 d_second_name_bin: 2,
                 d_tax_id_bin: 1,
                 docs_same_number_bin: "0x1",
                 gender_flag_bin: 1,
                 person_id: "eaa1e6cd-e6ad-4eef-8962-a15e702249e4",
                 residence_settlement_flag_bin: 1,
                 twins_flag_bin: 0
               } == bins

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
          "СМ-С1",
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
          "СMC1",
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
      person_addresses: [
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
