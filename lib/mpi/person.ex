defmodule MPI.Person do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  alias MPI.Repo

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "persons" do
    field :first_name, :string
    field :last_name, :string
    field :second_name, :string
    field :birth_date, :date
    field :birth_place, :string
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
    field :signature, :string
    field :inserted_by, :string
    field :updated_by, :string

    timestamps(type: :utc_datetime)
  end

  @fields ~W(
    first_name
    last_name
    second_name
    birth_date
    birth_place
    gender
    email
    tax_id
    national_id
    death_date
    is_active
    history
    signature
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
    :updated_by,
    :signature
  ]

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> cast_embed(:documents, with: &document_changeset/2)
    |> cast_embed(:addresses, with: &address_changeset/2)
    |> cast_embed(:phones, with: &phone_changeset/2)
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

  def search(%Ecto.Changeset{changes: parameters}) do
    {res, next_paging} =
    parameters
    |> get_query()
    |> Repo.page(%Ecto.Paging{limit: Confex.get(:mpi, :max_persons_result)})
  end

  def get_query(%{phone_number: phone_number} = changes) do
    params =
      changes
      |> Map.delete(:phone_number)
      |> Map.to_list()

    from s in MPI.Person,
      where: ^params,
      where: fragment("? @> ?", s.phones, ~s/[{"number":"#{phone_number}"}]/)
  end

  def get_query(params) do
    params = Map.to_list(params)
    from s in MPI.Person,
      where: ^params
  end
end
