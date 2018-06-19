defmodule MPI.PersonPhone do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias MPI.Person

  @derive {Poison.Encoder, only: [:type, :number]}
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "person_phones" do
    field(:type, :string)
    field(:number, :string)
    belongs_to(:person, Person)
    timestamps(type: :utc_datetime)
  end

  @fields [:number, :type]

  def changeset(%__MODULE__{} = person_phone, params \\ %{}) do
    person_phone
    |> cast(params, @fields)
    |> validate_required(@fields)
  end
end
