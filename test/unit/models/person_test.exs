defmodule MPI.PersonTest do
  use MPI.ModelCase, async: true

  alias MPI.Person
  alias MPI.Persons.PersonsAPI

  describe "Valid record" do
    test "successfully inserted in DB" do
      params = %{
        "first_name": "Петро",
        "last_name": "Іванов",
        "second_name": "Миколайович",
        "birth_date": "1991-08-19",
        "birth_country": "Україна",
        "birth_settlement": "Вінниця",
        "gender": "MALE",
        "email": "email@example.com",
        "tax_id": "3126509816",
        "national_id": "CC7150985243",
        "death_date": "2015-04-07",
        "status": "ACTIVE",
        "secret": "secret",
        "patient_signed": true,
        "process_disclosure_data_consent": true,
        "documents": [
          %{
            "type": "PASSPORT",
            "number": "120518"
          }
        ],
        "addresses": [
          %{
            "type": "RESIDENCE",
            "country": "UA",
            "area": "Житомирська",
            "region": "Бердичівський",
            "settlement_id": "6f9f817e-a27c-4213-8d4d-35c3b96496bc",
            "settlement": "Київ",
            "settlement_type": "CITY",
            "street_type": "STREET",
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
        ],
        "emergency_contact": %{
          "first_name": "Іван",
          "last_name": "Петров",
          "second_name": "Миколайович",
          "phones": [
            %{
              "type": "MOBILE",
              "number": "+380508912271"
            }
          ]
        },
        "confidant_person": [
          %{
            "first_name": "Микола",
            "last_name": "Петров",
            "second_name": "Іванович",
            "gender": "MALE",
            "birth_date": "1996-12-12",
            "birth_country": "Україна",
            "tax_id": "2222222225",
            "phones": [
              %{
                "number": "+380957790328",
                "type": "MOBILE"
              }
            ],
            "documents_person": [
              %{
                "number": "831221",
                "type": "PASSPORT"
              }
            ],
            "documents_relationship": [
              %{
                "number": "230972",
                "type": "NATIONAL_ID"
              }
            ]
          }
        ],
        "authentication_methods": [
          %{
            "type": "OTP",
            "number": "+380503410870"
          }
        ]
      }

      %Ecto.Changeset{valid?: true} = changeset = PersonsAPI.changeset(%Person{}, params)
      assert {:ok, _record} = Repo.insert(changeset)
    end
  end
end
