defmodule MPI.Persons.PersonSearch do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias EView.Changeset.Validators.PhoneNumber
  alias MPI.Persons.PersonSearch

  schema "persons" do
    field :ids, MPI.CommaParamsUUID
    field :first_name, :string
    field :last_name, :string
    field :second_name, :string
    field :birth_date, :date
    field :tax_id, :string
    field :phone_number, :string
  end

  @fields ~W(
    ids
    first_name
    last_name
    second_name
    birth_date
    tax_id
    phone_number
  )

  @required_fields [
    :first_name,
    :last_name,
    :birth_date,
  ]

  def changeset(%{"ids" => _} = params) do
    %PersonSearch{}
    |> cast(params, @fields)
    |> PhoneNumber.validate_phone_number(:phone_number)
  end

  def changeset(params) do
    %PersonSearch{}
    |> cast(params, @fields)
    |> validate_required(@required_fields)
    |> PhoneNumber.validate_phone_number(:phone_number)
  end
end
