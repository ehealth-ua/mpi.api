defmodule Core.PersonDocument do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Person

  @derive {Poison.Encoder, only: [:type, :number, :issued_by, :issued_at, :expiration_date]}
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "person_documents" do
    field(:type, :string)
    field(:number, :string)
    field(:issued_at, :string)
    field(:expiration_date, :string)
    field(:issued_by, :string)
    belongs_to(:person, Person)
    timestamps(type: :utc_datetime)
  end

  @fields [:type, :number, :issued_at, :expiration_date, :issued_by]
  @fields_required [:type, :number]

  def changeset(%__MODULE__{} = person_document, params \\ %{}) do
    person_document
    |> cast(params, @fields)
    |> validate_required(@fields_required)
  end
end
