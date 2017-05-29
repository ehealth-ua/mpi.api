defmodule MPI.Factory do
  @moduledoc """
  This module lists factories, a mean suitable
  for tests that involve preparation of DB data
  """
  use ExMachina.Ecto, repo: MPI.Repo

  def person_factory do
    %MPI.Person{
      version: sequence(:version, &"version-#{&1}"),
      first_name: sequence(:first_name, &"first_name-#{&1}"),
      last_name: sequence(:last_name, &"last_name-#{&1}"),
      second_name: sequence(:second_name, &"second_name-#{&1}"),
      birth_date: "1996-12-12",
      birth_place: sequence(:birth_place, &"birth_place-#{&1}"),
      gender: Enum.random(["MALE", "FEMALE"]),
      email: sequence(:email, &"email-#{&1}"),
      tax_id: sequence(:tax_id, &"tax_id-#{&1}"),
      death_date: "1997-12-12",
      is_active: true,
      documents: build_list(2, :document),
      addresses: build_list(2, :address),
      phones: build_list(1, :phone),
      secret: sequence(:secret, &"updated_by-#{&1}"),
      emergency_contact: build(:emergency_contact),
#      confidant_person: build(:confidant_person),
      status: Enum.random(["ACTIVE"]),
      inserted_by: sequence(:inserted_by, &"inserted_by-#{&1}"),
      updated_by: sequence(:updated_by, &"updated_by-#{&1}"),
      authentication_methods: %{}
    }
  end

  def emergency_contact_factory do
    %MPI.Person.EmergencyContact{
      first_name: sequence(:emergency_contact_first_name, &"first_name-#{&1}"),
      last_name: sequence(:emergency_contact_last_name, &"last_name-#{&1}"),
      second_name: sequence(:emergency_contact_second_name, &"second_name-#{&1}"),
      phones: build_list(1, :phone_emergency_contact),
    }
  end

  def confidant_person_factory do
    %MPI.Person.ConfidantPerson{
      first_name: sequence(:confidant_person_first_name, &"first_name-#{&1}"),
      last_name: sequence(:confidant_person_last_name, &"last_name-#{&1}"),
      second_name: sequence(:confidant_person_second_name, &"second_name-#{&1}"),
      birth_date: "1996-12-12",
      birth_place: sequence(:confidant_person_birth_place, &"birth_place-#{&1}"),
      gender: Enum.random(["MALE", "FEMALE"]),
      tax_id: sequence(:confidant_person_tax_id, &"tax_id-#{&1}"),
      phones: build_list(1, :phone),
      documents: build_list(2, :document),
    }
  end

  def address_factory do
    %MPI.Person.Address{
      type: Enum.random(["RESIDENCE", "REGISTRATION"]),
      country: Enum.random(["UA"]),
      area: sequence(:area, &"address-area-#{&1}"),
      region: sequence(:region, &"address-region-#{&1}"),
      city: sequence(:city, &"address-city-#{&1}"),
      city_type: Enum.random(["CITY"]),
      street: sequence(:street, &"address-street-#{&1}"),
      building: sequence(:building, &"address-building-#{&1}"),
      apartment: sequence(:apartment, &"address-apartment-#{&1}"),
      zip: sequence(:zip, &"address-zip-#{&1}"),

    }
  end

  def document_factory do
    %MPI.Person.Document{
      type: Enum.random(["PASSPORT"]),
      number: sequence(:document_number, &"document-number-#{&1}"),
      issue_date: random_date(),
      expiration_date: random_date(),
      issued_by: sequence(:issued_by, &"document-issued_by-#{&1}"),
    }
  end

  def phone_factory do
    %MPI.Person.Phone{
      type: Enum.random(["MOBILE", "LANDLINE"]),
      number: "+#{Enum.random(100_000_000..999_999_999)}"
    }
  end

  def phone_emergency_contact_factory do
    %MPI.Person.EmergencyContact.Phone{
      type: Enum.random(["MOBILE", "LANDLINE"]),
      number: "+#{Enum.random(100_000_000..999_999_999)}"
    }
  end

  def phone_confidant_person_factory do
    %MPI.Person.ConfidantPerson.Phone{
      type: Enum.random(["MOBILE", "LANDLINE"]),
      number: "+#{Enum.random(100_000_000..999_999_999)}"
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
