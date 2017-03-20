defmodule MPI.PersonTest do
  use MPI.ModelCase, async: true

  alias MPI.Person

  describe "Valid record" do
    test "successfully inserted in DB" do
      params = %{
        "first_name": "Петро",
        "last_name": "Іванов",
        "second_name": "Миколайович",
        "birth_date": "1991-08-19T00:00:00.000Z",
        "birth_place": "Вінниця, Україна",
        "gender": "MALE",
        "email": "email@example.com",
        "tax_id": "3126509816",
        "national_id": "CC7150985243",
        "death_date": "2015-04-07T00:00:00.000Z",
        "documents": [
          %{
            "type": "PASSPORT",
            "number": "120518",
            "issue_date": "2015-04-07T00:00:00.000Z",
            "expiry_date": "2015-04-07T00:00:00.000Z",
            "issued_by": "DMSU"
          }
        ],
        "addresses": [
          %{
            "type": "RESIDENCE",
            "country": "UA",
            "area": "Житомирська",
            "region": "Бердичівський",
            "city": "Київ",
            "city_type": "CITY",
            "street": "вул. Ніжинська",
            "building": "15",
            "apartment": "23",
            "zip": "02090"
          }
        ],
        "phones": [
          %{
            "type": "MOBILE",
            "number": "+380503410870"
          }
        ]
      }

      %Ecto.Changeset{valid?: true} = changeset = Person.changeset(%Person{}, params)
      assert {:ok, _record} = Repo.insert(changeset)
    end
  end
end
