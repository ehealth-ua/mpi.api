defmodule Deduplication.MatchTest do
  use Core.ModelCase, async: true
  import Mox

  alias Core.Repo
  alias Core.Person
  alias Core.PersonDocument
  alias Core.PersonPhone
  alias Core.MergeCandidate
  alias Core.Factory
  alias Deduplication.Match, as: Deduplication

  setup do
    expect(ClientMock, :post!, fn _url, _body, _headers -> %HTTPoison.Response{status_code: 200} end)
    :ok
  end

  describe "run/0" do
    test "subsequent runs skip found duplicates" do
      person_attrs = Factory.person_factory()

      person_attrs_dup1 =
        build_duplicate(person_attrs, %{
          first_name: "Egor",
          last_name: "Letov",
          birth_date: ~D[2000-01-01]
        })

      person_attrs_dup2 =
        build_duplicate(person_attrs, %{
          first_name: "Anna",
          last_name: "Karenina",
          birth_date: ~D[2000-01-01]
        })

      insert(person_attrs, %{inserted_at: within_hours(49)})
      insert(person_attrs_dup1, %{inserted_at: within_hours(27)})
      insert(person_attrs_dup2, %{inserted_at: within_hours(13)})

      Deduplication.run()
      assert 2 = Repo.one(from(mc in MergeCandidate, select: count(1)))

      Deduplication.run()
      assert 2 = Repo.one(from(mc in MergeCandidate, select: count(1)))

      verify!(ClientMock)
    end

    test "multiple diplicates of same records were created during depth window" do
      person_attrs = Factory.person_factory()

      person_attrs_dup1 =
        build_duplicate(person_attrs, %{
          first_name: "Egor",
          last_name: "Letov",
          birth_date: ~D[2000-01-01]
        })

      person_attrs_dup2 =
        build_duplicate(person_attrs, %{
          first_name: "Anna",
          last_name: "Karenina",
          birth_date: ~D[2000-01-01]
        })

      person = insert(person_attrs, %{inserted_at: within_hours(49)})
      person_dup1 = insert(person_attrs_dup1, %{inserted_at: within_hours(27)})
      person_dup2 = insert(person_attrs_dup2, %{inserted_at: within_hours(13)})

      Deduplication.run()

      valid_pairs = [
        [older: person, newer: person_dup2],
        [older: person_dup1, newer: person_dup2]
      ]

      Enum.each(valid_pairs, fn [older: older, newer: newer] ->
        query =
          from(
            mc in MergeCandidate,
            where: mc.master_person_id == ^newer.id,
            where: mc.person_id == ^older.id
          )

        assert Repo.one(query)
        verify!(ClientMock)
      end)
    end

    test "compare_lists/2" do
      list1 = [%PersonDocument{number: "111115", type: "BIRTH_CERTIFICATE"}]
      list2 = [%PersonDocument{number: "111111", type: "BIRTH_CERTIFICATE"}]
      assert :no_match = Deduplication.compare_lists(list1, list2)

      list1 = [%PersonDocument{number: "111111", type: "BIRTH_CERTIFICATE"}]
      list2 = [%PersonDocument{number: "111111", type: "BIRTH_CERTIFICATE"}]
      assert :match = Deduplication.compare_lists(list1, list2)

      list1 = nil
      list2 = [%PersonDocument{number: "111111", type: "BIRTH_CERTIFICATE"}]
      assert :no_match = Deduplication.compare_lists(list1, list2)

      list1 = [%PersonDocument{number: "111115", type: "BIRTH_CERTIFICATE"}]
      list2 = nil
      assert :no_match = Deduplication.compare_lists(list1, list2)

      list1 = nil
      list2 = nil
      assert :match = Deduplication.compare_lists(list1, list2)

      list1 = []
      list2 = []
      assert :match = Deduplication.compare_lists(list1, list2)
    end

    test "pulls candidates and runs them through score matching" do
      person1_attrs = Factory.person_factory()

      person1_attrs_dup =
        build_duplicate(person1_attrs, %{
          first_name: "Egor",
          last_name: "Letov",
          birth_date: ~D[2000-01-01]
        })

      person1 = insert(person1_attrs, %{inserted_at: within_hours(13)})
      person1_dup = insert(person1_attrs_dup, %{inserted_at: within_hours(3 * 24 + 5)})

      person2_attrs = Factory.person_factory()

      person2_attrs_dup =
        build_duplicate(person2_attrs, %{
          first_name: "Egor",
          last_name: "Letov",
          birth_date: ~D[2000-01-01]
        })

      person2 = insert(person2_attrs, %{inserted_at: within_hours(41)})
      person2_dup = insert(person2_attrs_dup, %{inserted_at: within_hours(73)})

      Deduplication.run()
      verify!(ClientMock)

      valid_pairs = [
        [older: person1_dup, newer: person1],
        [older: person2_dup, newer: person2]
      ]

      Enum.each(valid_pairs, fn [older: older, newer: newer] ->
        query =
          from(
            mc in MergeCandidate,
            where: mc.master_person_id == ^newer.id,
            where: mc.person_id == ^older.id
          )

        duplicate_record = Repo.one(query)

        assert %{
                 "score" => 1.3,
                 "weights" => _
               } = duplicate_record.details

        assert %{
                 "depth" => 20,
                 "fields" => %{
                   "birth_date" => %{"match" => 0.5, "no_match" => -0.1},
                   "documents" => %{"match" => 0.3, "no_match" => -0.1},
                   "first_name" => %{"match" => 0.1, "no_match" => -0.1},
                   "last_name" => %{"match" => 0.2, "no_match" => -0.1},
                   "unzr" => %{"match" => 0.4, "no_match" => -0.1},
                   "phones" => %{"match" => 0.3, "no_match" => -0.1},
                   "second_name" => %{"match" => 0.1, "no_match" => -0.1},
                   "tax_id" => %{"match" => 0.5, "no_match" => -0.1}
                 },
                 "score" => "0.8"
               } = duplicate_record.config

        assert "active" == Repo.get(Person, newer.id).status
        assert "inactive" == Repo.get(Person, older.id).status
      end)
    end
  end

  describe "find_duplicates/3" do
    test "returns exact duplicates" do
      persons = [{"a", 3}, {"a", 2}, {"a", 1}]
      candidates = [{"a", 3}, {"a", 2}]

      expected_result = [{{true, nil}, {"a", 3}, {"a", 2}}, {{true, nil}, {"a", 3}, {"a", 1}}]

      result =
        Deduplication.find_duplicates(candidates, persons, fn candidate, person ->
          {elem(candidate, 0) == elem(person, 0), nil}
        end)

      assert expected_result == result
    end
  end

  describe "match_score/3" do
    test "calculates the match score for a given pair of persons" do
      person1 = %Person{
        tax_id: "3087232628",
        first_name: "Петро",
        last_name: "Бондар",
        second_name: "Миколайович",
        birth_date: "12.06.1993",
        documents: [
          %PersonDocument{
            type: "PASSPORT",
            number: "ВВ123456"
          }
        ],
        unzr: "РП-765123",
        phones: [
          %PersonPhone{type: "MOBILE", number: "+380501234567"},
          %PersonPhone{type: "MOBILE", number: "+380507654321"}
        ]
      }

      person2 = %Person{
        tax_id: "3087232628",
        first_name: "Педро",
        last_name: "Бондар",
        second_name: "Миколайович",
        birth_date: "13.06.1993",
        documents: [
          %PersonDocument{
            type: "PASSPORT",
            number: "ВВ654321"
          }
        ],
        unzr: "РП-765123",
        phones: [
          %PersonPhone{type: "MOBILE", number: "+380501234567"}
        ]
      }

      person3 = %Person{person1 | phones: []}
      person4 = %Person{person2 | phones: []}

      comparison_fields = %{
        tax_id: [match: 0.1, no_match: -0.1],
        first_name: [match: 0.1, no_match: -0.1],
        last_name: [match: 0.1, no_match: -0.1],
        second_name: [match: 0.1, no_match: -0.1],
        birth_date: [match: 0.1, no_match: -0.1],
        documents: [match: 0.1, no_match: -0.1],
        unzr: [match: 0.1, no_match: -0.1],
        phones: [match: 0.1, no_match: -0.1]
      }

      assert {0.2, _} = Deduplication.match_score(person1, person2, comparison_fields)
      assert {0.6, _} = Deduplication.match_score(person1, person3, comparison_fields)
      assert {0.0, _} = Deduplication.match_score(person1, person4, comparison_fields)
      assert {0.0, _} = Deduplication.match_score(person2, person3, comparison_fields)
      assert {0.6, _} = Deduplication.match_score(person2, person4, comparison_fields)
      assert {0.2, _} = Deduplication.match_score(person3, person4, comparison_fields)
      assert {0.8, _} = Deduplication.match_score(person1, person1, comparison_fields)
    end

    test "match score is correct (#1674)" do
      person1 = %Person{
        tax_id: "",
        first_name: "Сергій",
        last_name: "Закусило",
        second_name: "Євгенович",
        birth_date: "2007-12-18",
        documents: [
          %PersonDocument{
            type: "BIRTH_CERTIFICATE",
            number: "11111111111"
          }
        ],
        unzr: "",
        phones: [
          %PersonPhone{
            type: "MOBILE",
            number: "+380965992121"
          }
        ]
      }

      person2 = %Person{
        tax_id: "",
        first_name: "Діана",
        last_name: "Закусило",
        second_name: "Петрівна",
        birth_date: "2017-11-11",
        documents: [
          %PersonDocument{
            type: "BIRTH_CERTIFICATE",
            number: "456789"
          }
        ],
        unzr: "",
        phones: [
          %PersonPhone{
            type: "MOBILE",
            number: "+380639368040"
          }
        ]
      }

      comparison_fields = %{
        tax_id: [match: 0.5, no_match: -0.1],
        first_name: [match: 0.1, no_match: -0.1],
        last_name: [match: 0.2, no_match: -0.1],
        second_name: [match: 0.1, no_match: -0.1],
        birth_date: [match: 0.5, no_match: -0.1],
        documents: [match: 0.3, no_match: -0.1],
        unzr: [match: 0.4, no_match: -0.1],
        phones: [match: 0.3, no_match: -0.1]
      }

      assert {0.6,
              %{
                birth_date: %{
                  candidate: "2007-12-18",
                  person: "2017-11-11",
                  weight: -0.1
                },
                first_name: %{
                  candidate: "Сергій",
                  person: "Діана",
                  weight: -0.1
                },
                last_name: %{
                  candidate: "Закусило",
                  person: "Закусило",
                  weight: 0.2
                },
                unzr: %{candidate: "", person: "", weight: 0.4},
                documents: %{
                  candidate: [
                    %{number: "11111111111", type: "BIRTH_CERTIFICATE"}
                  ],
                  person: [%{number: "456789", type: "BIRTH_CERTIFICATE"}],
                  weight: -0.1
                },
                phones: %{
                  candidate: [%{number: "+380965992121", type: "MOBILE"}],
                  person: [%{number: "+380639368040", type: "MOBILE"}],
                  weight: -0.1
                },
                second_name: %{
                  candidate: "Євгенович",
                  person: "Петрівна",
                  weight: -0.1
                },
                tax_id: %{candidate: "", person: "", weight: 0.5}
              }} = Deduplication.match_score(person1, person2, comparison_fields)
    end
  end

  defp insert(struct, attrs) do
    struct
    |> Ecto.Changeset.change(attrs)
    |> Repo.insert!()
  end

  defp build_duplicate(person, differences) do
    Map.merge(person, differences)
  end

  defp within_hours(number) do
    Timex.shift(Timex.now(), hours: -number)
  end
end
