defmodule Mpi.Person do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "persons" do
    field :first_name, :string
    field :last_name, :string
    field :second_name, :string
    field :birth_date, :date
    field :gender, :string
    field :email, :string
    field :tax_id, :string
    field :national_id, :string
    field :death_date, :date
    field :is_active, :boolean
    field :documents, {:array, :map}
    field :addresses, {:array, :map}
    field :phones, {:array, :map}
    field :history, {:array, :map}
    field :inserted_by, :string
    field :updated_by, :string

    timestamps(type: :utc_datetime)
  end

  @fields ~W(
    first_name
    last_name
    second_name
    birth_date
    gender
    email
    tax_id
    national_id
    death_date
    is_active
    documents
    addresses
    phones
    history
    inserted_by
    updated_by
  )

  @required_fields [
    :first_name,
    :last_name,
    :birth_date,
    :gender,
    :inserted_by,
    :updated_by
  ]

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
  end
end
