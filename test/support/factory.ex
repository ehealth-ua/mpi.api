defmodule MPI.Factory do
  @moduledoc """
  This module lists factories, a mean suitable
  for tests that involve preparation of DB data
  """
  use ExMachina.Ecto, repo: MPI.Repo

  def person_factory do
    %MPI.Person{
      first_name: sequence(:first_name, &"first_name-#{&1}"),
      last_name: sequence(:last_name, &"last_name-#{&1}"),
      second_name: sequence(:second_name, &"second_name-#{&1}"),
      birth_date: random_date(),
      gender: sequence(:gender, &"gender-#{&1}"),
      email: sequence(:email, &"email-#{&1}"),
      tax_id: sequence(:tax_id, &"tax_id-#{&1}"),
      national_id: sequence(:national_id, &"national_id-#{&1}"),
      death_date: random_date(),
      history: [],
      is_active: true,
      phones: build_list(1, :phone),
      documents: build_list(2, :document),
      addresses: build_list(2, :address),
      inserted_by: sequence(:inserted_by, &"inserted_by-#{&1}"),
      updated_by: sequence(:updated_by, &"updated_by-#{&1}"),
    }
  end

  def address_factory do
    %MPI.Person.Address{
      type: sequence(:address_type, &"address-type-#{&1}"),
      country: sequence(:country, &"address-country-#{&1}"),
      area: sequence(:area, &"address-area-#{&1}"),
      region: sequence(:region, &"address-region-#{&1}"),
      city: sequence(:city, &"address-city-#{&1}"),
      city_type: sequence(:city_type, &"address-city_type-#{&1}"),
      street: sequence(:street, &"address-street-#{&1}"),
      building: sequence(:building, &"address-building-#{&1}"),
      apartment: sequence(:apartment, &"address-apartment-#{&1}"),
      zip: sequence(:zip, &"address-zip-#{&1}"),

    }
  end

  def document_factory do
    %MPI.Person.Document{
      type: sequence(:document_type, &"document-type-#{&1}"),
      number: sequence(:document_number, &"document-number-#{&1}"),
      issue_date: random_date(),
      expiration_date: random_date(),
      issued_by: sequence(:issued_by, &"document-issued_by-#{&1}"),
    }
  end

  def phone_factory do
    %MPI.Person.Phone{
      type: sequence(:phone_type, &"phone-type-#{&1}"),
      number: sequence(:document_number, &"phone-number-#{&1}"),
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

  def random_date, do: DateTime.utc_now() |> DateTime.to_date()
end
