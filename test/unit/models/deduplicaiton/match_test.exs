defmodule MPI.Deduplication.MatchTest do
  use MPI.ModelCase, async: true

  alias MPI.Repo
  alias MPI.Person
  alias MPI.MergeCandidate

  alias MPI.Deduplication.Match, as: Deduplication
  alias MPI.Factory

  describe "run/0" do
    test "subsequent runs skip found duplicates" do
      person_attrs      = Factory.person_factory
      person_attrs_dup1 = build_duplicate(person_attrs, %{
        "first_name" => "Egor", "last_name" => "Letov", "birth_date" => "2000-01-01"
      })
      person_attrs_dup2 = build_duplicate(person_attrs, %{
        "first_name" => "Anna", "last_name" => "Karenina", "birth_date" => "2000-01-01"
      })

      insert(person_attrs, %{inserted_at: within_hours(49)})
      insert(person_attrs_dup1, %{inserted_at: within_hours(27)})
      insert(person_attrs_dup2, %{inserted_at: within_hours(13)})

      Deduplication.run()
      assert 2 = Repo.one(from mc in MergeCandidate, select: count(1))

      Deduplication.run()
      assert 2 = Repo.one(from mc in MergeCandidate, select: count(1))
    end

    test "multiple diplicates of same records were created during depth window" do
      person_attrs      = Factory.person_factory
      person_attrs_dup1 = build_duplicate(person_attrs, %{
        "first_name" => "Egor", "last_name" => "Letov", "birth_date" => "2000-01-01"
      })
      person_attrs_dup2 = build_duplicate(person_attrs, %{
        "first_name" => "Anna", "last_name" => "Karenina", "birth_date" => "2000-01-01"
      })

      person      = insert(person_attrs, %{inserted_at: within_hours(49)})
      person_dup1 = insert(person_attrs_dup1, %{inserted_at: within_hours(27)})
      person_dup2 = insert(person_attrs_dup2, %{inserted_at: within_hours(13)})

      Deduplication.run()

      valid_pairs = [
        [older: person, newer: person_dup2],
        [older: person_dup1, newer: person_dup2]
      ]

      Enum.each valid_pairs, fn [older: older, newer: newer] ->
        query =
          from mc in MergeCandidate,
            where: mc.master_person_id == ^newer.id,
            where: mc.person_id == ^older.id

        assert Repo.one(query)
      end
    end

    test "pulls candidates and runs them through score matching" do
      person1_attrs     = Factory.person_factory
      person1_attrs_dup = build_duplicate(person1_attrs, %{
        "first_name" => "Egor", "last_name" => "Letov", "birth_date" => "2000-01-01"
      })
      person1           = insert(person1_attrs, %{inserted_at: within_hours(13)})
      person1_dup       = insert(person1_attrs_dup, %{inserted_at: within_hours(3 * 24 + 5)})

      person2_attrs     = Factory.person_factory
      person2_attrs_dup = build_duplicate(person2_attrs, %{
        "first_name" => "Egor", "last_name" => "Letov", "birth_date" => "2000-01-01"
      })
      person2           = insert(person2_attrs, %{inserted_at: within_hours(41)})
      person2_dup       = insert(person2_attrs_dup, %{inserted_at: within_hours(73)})

      Deduplication.run()

      valid_pairs = [
        [older: person1_dup, newer: person1],
        [older: person2_dup, newer: person2]
      ]

      Enum.each valid_pairs, fn [older: older, newer: newer] ->
        query =
          from mc in MergeCandidate,
            where: mc.master_person_id == ^newer.id,
            where: mc.person_id == ^older.id

        assert Repo.one(query)
      end
    end
  end

  describe "find_duplicates/3" do
    test "returns exact duplicates" do
      persons = [{"a", 3}, {"a", 2}, {"a", 1}]
      candidates = [{"a", 3}, {"a", 2}]

      expected_result = [{{"a", 3}, {"a", 2}}, {{"a", 3}, {"a", 1}}]

      result =
        Deduplication.find_duplicates(candidates, persons, fn candidate, person ->
          elem(candidate, 0) == elem(person, 0)
        end)

      assert expected_result == result
    end
  end

  describe "match_score/3" do
    test "calculates the match score for a given pair of persons" do
      person1 = %Person{
        tax_id:       "3087232628",
        first_name:   "Петро",
        last_name:    "Бондар",
        second_name:  "Миколайович",
        birth_date:   "12.06.1993",
        documents:    [
          %{
            "type" => "PASSPORT",
            "number" => "ВВ123456"
          }
        ],
        national_id:  "РП-765123",
        phones: [
          %{"type" => "MOBILE", "number" => "+380501234567"},
          %{"type" => "MOBILE", "number" => "+380507654321"}
        ]
      }

      person2 = %Person{
        tax_id:       "3087232628",
        first_name:   "Педро",
        last_name:    "Бондар",
        second_name:  "Миколайович",
        birth_date:   "13.06.1993",
        documents:    [
          %{
            "type" => "PASSPORT",
            "number" => "ВВ654321"
          }
        ],
        national_id:  "РП-765123",
        phones: [
          %{"type" => "MOBILE", "number" => "+380501234567"}
        ]
      }

      comparison_fields = %{
        tax_id:       [match: 0.1, no_match: -0.1],
        first_name:   [match: 0.1, no_match: -0.1],
        last_name:    [match: 0.1, no_match: -0.1],
        second_name:  [match: 0.1, no_match: -0.1],
        birth_date:   [match: 0.1, no_match: -0.1],
        documents:    [match: 0.1, no_match: -0.1],
        national_id:  [match: 0.1, no_match: -0.1],
        phones:       [match: 0.1, no_match: -0.1]
      }

      assert 0.2 = Deduplication.match_score(person1, person2, comparison_fields)
    end
  end

  defp insert(struct, attrs) do
    struct
    |> Ecto.Changeset.change(attrs)
    |> MPI.Repo.insert!
  end

  defp build_duplicate(person, differences) do
    Map.merge(person, differences)
  end

  defp within_hours(number) do
    Timex.shift(Timex.now(), hours: -number)
  end
end
