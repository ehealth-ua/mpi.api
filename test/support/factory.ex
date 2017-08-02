defmodule MPI.Factory do
  @moduledoc """
  This module lists factories, a mean suitable
  for tests that involve preparation of DB data
  """
  use ExMachina.Ecto, repo: MPI.Repo

  def merge_candidate_factory do
    %MPI.MergeCandidate{
      person: build(:person),
      master_person: build(:person)
    }
  end

  def person_factory, do: struct(MPI.Person, person_params_factory())

  def person_params_factory do
    %{
      first_name: sequence(:first_name, &"first_name-#{&1}"),
      last_name: sequence(:last_name, &"last_name-#{&1}"),
      second_name: sequence(:second_name, &"second_name-#{&1}"),
      birth_date: ~D[1996-12-12],
      birth_country: sequence(:birth_country, &"birth_country-#{&1}"),
      birth_settlement: sequence(:birth_settlement, &"birth_settlement-#{&1}"),
      gender: Enum.random(["MALE", "FEMALE"]),
      email: sequence(:email, &"email#{&1}@mail.com"),
      tax_id: sequence(:tax_id, &"tax_id-#{&1}"),
      documents: build_list(2, :document),
      addresses: build_list(2, :address),
      phones: build_list(1, :phone),
      secret: sequence(:secret, &"secret-#{&1}"),
      emergency_contact: build(:emergency_contact),
      confidant_person: build_list(1, :confidant_person),
      secret: sequence(:secret, &"secret-#{&1}"),
      patient_signed: true,
      process_disclosure_data_consent: true,
      authentication_methods: build_list(2, :authentication_method)
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
      settlement_id: Ecto.UUID.generate(),
      street_type: Enum.random(["STREET"]),
      street: sequence(:street, &"address-street-#{&1}"),
      building: sequence(:building, &"#{&1 + 1}а"),
      apartment: sequence(:apartment, &"address-apartment-#{&1}"),
      zip: to_string(Enum.random(10000..99999))
    }
  end

  def document_factory do
    %{
      type: Enum.random(["PASSPORT", "NATIONAL_ID"]),
      number: sequence(:document_number, &"document-number-#{&1}")
    }
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

  def build_factory_params(factory, overrides \\ []) do
    factory
    |> MPI.Factory.build(overrides)
    |> schema_to_map()
  end

  def schema_to_map(schema) do
    schema
    |> Map.drop([:__struct__, :__meta__])
    |> Enum.reduce(%{}, fn
      {key, %Ecto.Association.NotLoaded{}}, acc ->
        acc
        |> Map.put(key, %{})
      {key, %{__struct__: _} = map}, acc ->
        acc
        |> Map.put(key, schema_to_map(map))
      {key, [%{__struct__: _}|_] = list}, acc ->
          acc
          |> Map.put(key, list_schemas_to_map(list))
      {key, val}, acc ->
        acc
        |> Map.put(key, val)
    end)
  end

  def list_schemas_to_map(list) do
    Enum.map(list, fn(x) -> schema_to_map(x) end)
  end

  def random_date, do: DateTime.to_iso8601(DateTime.utc_now())
end
