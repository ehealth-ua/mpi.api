defmodule Core.PersonAddress do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Person
  alias Ecto.UUID

  @fields ~w(
   type
   country
   area
   region
   settlement
   settlement_type
   settlement_id
   street_type
   street
   building
   apartment
   zip
   person_last_name
   person_first_name)a

  @fields_required ~w(
  person_last_name
  person_first_name
  type
  country
  area
  settlement
  settlement_type
  settlement_id)a

  @derive {Poison.Encoder, only: @fields}

  @primary_key {:id, UUID, autogenerate: true}
  @foreign_key_type UUID
  schema "person_addresses" do
    field(:type, :string)
    field(:country, :string)
    field(:area, :string)
    field(:region, :string)
    field(:settlement, :string)
    field(:settlement_type, :string)
    field(:settlement_id, UUID)
    field(:street_type, :string)
    field(:street, :string)
    field(:building, :string)
    field(:apartment, :string)
    field(:zip, :string)
    field(:person_first_name, :string)
    field(:person_last_name, :string)

    belongs_to(:person, Person)
    timestamps(type: :utc_datetime)
  end

  def cast_addresses(%__MODULE__{} = person_address, params \\ %{}, person_changeset, person) do
    first_name = person_changeset.changes[:first_name] || person.first_name
    last_name = person_changeset.changes[:last_name] || person.last_name

    changeset(
      person_address,
      Map.merge(params, %{
        "person_first_name" => first_name,
        "person_last_name" => last_name
      })
    )
  end

  def changeset(%__MODULE__{} = person_address, params \\ %{}) do
    person_address
    |> cast(params, @fields)
    |> validate_required(@fields_required)
  end

  def fields, do: @fields
end
