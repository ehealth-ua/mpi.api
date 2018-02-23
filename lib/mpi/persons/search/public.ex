defmodule MPI.Persons.Search.Public do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias EView.Changeset.Validators.PhoneNumber

  schema "persons" do
    field(:ids, MPI.CommaParamsUUID)
    field(:first_name, :string)
    field(:last_name, :string)
    field(:second_name, :string)
    field(:birth_date, :date)
    field(:tax_id, :string)
    field(:phone_number, :string)
  end

  @fields_required ~w(first_name last_name birth_date)a

  @fields_optional ~w(
    ids
    second_name
    tax_id
    phone_number
  )a

  def changeset(%{"ids" => _} = params) do
    %__MODULE__{}
    |> cast(params, @fields_required ++ @fields_optional)
    |> PhoneNumber.validate_phone_number(:phone_number)
  end

  def changeset(params) do
    %__MODULE__{}
    |> cast(params, @fields_required ++ @fields_optional)
    |> validate_required(@fields_required)
    |> PhoneNumber.validate_phone_number(:phone_number)
  end
end
