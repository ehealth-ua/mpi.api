defmodule Core.Factory do
  @moduledoc """
  This module lists factories, a mean suitable
  for tests that involve preparation of DB data
  """
  use ExMachina.Ecto, repo: Core.Repo
  alias Ecto.UUID
  alias Core.MergeCandidate
  alias Core.Person
  alias Core.PersonDocument
  alias Core.PersonPhone
  alias Core.PersonUpdate

  @person_status_active Core.Person.status(:active)

  def merge_candidate_factory do
    %MergeCandidate{
      status: "NEW",
      config: %{},
      person: build(:person),
      master_person: build(:person)
    }
  end

  def person_factory do
    birthday = ~D[1996-12-12]

    %Person{
      version: "0.1",
      first_name: sequence(:first_name, &"first_name-#{&1}"),
      last_name: sequence(:last_name, &"last_name-#{&1}"),
      second_name: sequence(:second_name, &"second_name-#{&1}"),
      birth_date: birthday,
      birth_country: sequence(:birth_country, &"birth_country-#{&1}"),
      birth_settlement: sequence(:birth_settlement, &"birth_settlement-#{&1}"),
      gender: Enum.random(["MALE", "FEMALE"]),
      email: sequence(:email, &"email#{&1}@mail.com"),
      tax_id: sequence(:tax_id, &"tax_id-#{&1}"),
      no_tax_id: false,
      unzr: sequence(:unzr, &"#{birthday}-#{&1}"),
      death_date: ~D[2117-11-09],
      preferred_way_communication: "email",
      is_active: true,
      addresses: build_list(2, :address),
      secret: sequence(:secret, &"secret-#{&1}"),
      emergency_contact: build(:emergency_contact),
      confidant_person: build_list(1, :confidant_person),
      patient_signed: true,
      process_disclosure_data_consent: true,
      status: @person_status_active,
      inserted_by: UUID.generate(),
      updated_by: UUID.generate(),
      authentication_methods: build_list(2, :authentication_method),
      merged_ids: [],
      phones: build_list(1, :person_phone),
      documents: build_list(2, :person_document)
    }
  end

  def person_update_factory do
    %PersonUpdate{
      person_id: UUID.generate(),
      status: Person.status(:active),
      updated_by: UUID.generate()
    }
  end

  def person_document_factory do
    Map.merge(
      %PersonDocument{},
      make_document(Enum.random(~w(PASSPORT NATIONAL_ID BIRTH_CERTIFICATE)))
    )
  end

  def person_phone_factory do
    %PersonPhone{
      person_id: UUID.generate(),
      type: Enum.random(["MOBILE", "LANDLINE"]),
      number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}"
    }
  end

  def emergency_contact_factory do
    %{
      first_name: sequence(:emergency_contact_first_name, &"first_name-#{&1}"),
      last_name: sequence(:emergency_contact_last_name, &"last_name-#{&1}"),
      second_name: sequence(:emergency_contact_second_name, &"second_name-#{&1}"),
      phones: build_list(1, :phone)
    }
  end

  def confidant_person_factory do
    %{
      relation_type: Enum.random(["PRIMARY", "SECONDARY"]),
      first_name: sequence(:confidant_person_first_name, &"first_name-#{&1}"),
      last_name: sequence(:confidant_person_last_name, &"last_name-#{&1}"),
      second_name: sequence(:confidant_person_second_name, &"second_name-#{&1}"),
      birth_date: "1996-12-12",
      birth_country: sequence(:confidant_person_birth_country, &"birth_country-#{&1}"),
      birth_settlement: sequence(:confidant_person_birth_settlement, &"birth_settlement-#{&1}"),
      gender: Enum.random(["MALE", "FEMALE"]),
      tax_id: sequence(:confidant_person_tax_id, &"tax_id-#{&1}"),
      secret: sequence(:confidant_person_secret, &"secret-#{&1}"),
      phones: build_list(1, :phone),
      documents_person: build_list(2, :document),
      documents_relationship: build_list(2, :document)
    }
  end

  def address_factory do
    %{
      type: Enum.random(["RESIDENCE", "REGISTRATION"]),
      country: Enum.random(["UA"]),
      area: sequence(:area, &"address-area-#{&1}"),
      region: sequence(:region, &"address-region-#{&1}"),
      settlement: sequence(:settlement, &"address-settlement-#{&1}"),
      settlement_type: Enum.random(["CITY"]),
      settlement_id: UUID.generate(),
      street_type: Enum.random(["STREET"]),
      street: sequence(:street, &"address-street-#{&1}"),
      building: sequence(:building, &"#{&1 + 1}а"),
      apartment: sequence(:apartment, &"address-apartment-#{&1}"),
      zip: to_string(Enum.random(10000..99999))
    }
  end

  def document_factory do
    make_document(Enum.random(~w(PASSPORT NATIONAL_ID BIRTH_CERTIFICATE)))
  end

  def phone_factory do
    %{
      type: Enum.random(["MOBILE", "LANDLINE"]),
      number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}"
    }
  end

  def authentication_method_factory do
    %{
      type: Enum.random(["OTP", "OFFLINE"]),
      phone_number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}"
    }
  end

  defp make_document("NATIONAL_ID") do
    %{
      type: "NATIONAL_ID",
      number: document_number(9),
      issued_by: document_number(4),
      issued_at: add_random_years(0, 2, -1),
      expiration_date: add_random_years(10, 12)
    }
  end

  defp make_document("PASSPORT") do
    %{
      type: "PASSPORT",
      number: "#{random_letter()}#{random_letter()}#{document_number(6)}",
      issued_by: "#{city()} РОУ ВМУ МВС в #{region()} області",
      issued_at: add_random_years(2, 10, -1)
    }
  end

  defp make_document("BIRTH_CERTIFICATE") do
    %{
      type: "BIRTH_CERTIFICATE",
      number:
        1..16
        |> Enum.map(fn _ -> random_letter() end)
        |> Enum.join(random_letter()),
      issued_by: "#{city()} РОУ ВМУ МВС в #{region()} області",
      issued_at: add_random_years(0, 16, -1),
      expiration_date: add_random_years(0, 16)
    }
  end

  defp city, do: Enum.random(~w(Десняньским Яворівським))
  defp region, do: Enum.random(~w(Чернігівській Львівській))

  defp add_random_years(min, max, koef \\ 1),
    do: Date.utc_today() |> Date.add(koef * Enum.random(min..max) * 365) |> Date.to_string()

  defp document_number(length) do
    min = Kernel.trunc(:math.pow(10, length - 1))
    max = Kernel.trunc(:math.pow(10, length)) - 1
    min..max |> Enum.random() |> Integer.to_string()
  end

  defp random_letter do
    List.to_string([Enum.random(?А..?Я)])
  end
end
