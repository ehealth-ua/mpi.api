defmodule Mpi.PersonHist do
  use Ecto.Schema

  import Ecto.Changeset

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "persons_hist" do
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
    embeds_many :documents, Document do
      field :type, :string
      field :number, :string
      field :issue_date, :date
      field :expiration_date, :date
      field :issued_by, :string
    end
    embeds_many :addresses, Address do
      field :type, :string
      field :country, :string
      field :area, :string
      field :region, :string
      field :city, :string
      field :city_type, :string
      field :street, :string
      field :building, :string
      field :apartment, :string
      field :zip, :string
    end
    embeds_many :phones, Phone do
      field :type, :string
      field :number, :string
    end
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
    history
    inserted_by
    updated_by
  )

  @document_fields ~W(
    type
    number
    issue_date
    expiration_date
    issued_by
  )

  @address_fields ~W(
    type
    number
    type
    country
    area
    region
    city
    city_type
    street
    building
    apartment
    zip
  )

  @phone_fields ~W(
    type
    number
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
    |> cast_embed(:documents, with: &document_changeset/2)
    |> validate_required(@required_fields)
  end

  def document_changeset(struct, params) do
    struct
    |> cast(params, @document_fields)
  end

  def address_changeset(struct, params) do
    struct
    |> cast(params, @address_fields)
  end

  def phone_changeset(struct, params) do
    struct
    |> cast(params, @phone_fields)
  end
end
