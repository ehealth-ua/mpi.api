defmodule MPI.Person do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset
  import Ecto.Query
  alias MPI.Repo

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "persons" do
    field :version, :string, default: "default"
    field :first_name, :string
    field :last_name, :string
    field :second_name, :string
    field :birth_date, :date
    field :birth_place, :string
    field :gender, :string
    field :email, :string
    field :tax_id, :string
    field :death_date, :date
    field :is_active, :boolean, default: true
    embeds_many :documents, Document, on_replace: :delete do
      field :type, :string
      field :number, :string
      field :issue_date, :utc_datetime
      field :expiration_date, :utc_datetime
      field :issued_by, :string
    end
    embeds_many :addresses, Address, on_replace: :delete do
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
    embeds_many :phones, Phone, on_replace: :delete do
      field :type, :string
      field :number, :string
    end
    field :secret, :binary
    embeds_one :emergency_contact, EmergencyContact, on_replace: :delete do
      field :first_name, :string
      field :last_name, :string
      field :second_name, :string
      embeds_many :phones, Phone, on_replace: :delete do
        field :type, :string
        field :number, :string
      end
    end
    embeds_one :confidant_person, ConfidantPerson, on_replace: :delete do
      field :first_name, :string
      field :last_name, :string
      field :second_name, :string
      field :birth_date, :date
      field :birth_place, :string
      field :gender, :string
      field :tax_id, :string
      embeds_many :phones, Phone, on_replace: :delete do
        field :type, :string
        field :number, :string
      end
      embeds_many :documents, Document, on_replace: :delete do
        field :type, :string
        field :number, :string
        field :issue_date, :utc_datetime
        field :expiration_date, :utc_datetime
        field :issued_by, :string
      end
    end
    field :status, :string
    field :inserted_by, :string, default: "default"
    field :updated_by, :string, default: "default"
    field :authentication_methods, {:array, :map}

    timestamps(type: :utc_datetime)
  end

  @fields ~W(
    version
    first_name
    last_name
    second_name
    birth_date
    birth_place
    gender
    email
    tax_id
    death_date
    is_active
    secret
    status
    inserted_by
    updated_by
    authentication_methods
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

  @emergency_contact_fields ~W(
    first_name
    last_name
    second_name
  )

  @confidant_person_fields ~W(
    first_name
    last_name
    second_name
    birth_date
    birth_place
    gender
    tax_id
  )

  @phone_fields ~W(
    type
    number
  )

  @required_fields [
    :version,
    :first_name,
    :last_name,
    :birth_date,
    :gender,
    :status,
    :inserted_by,
    :updated_by
  ]

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
    |> validate_inclusion(:gender, ["MALE", "FEMALE"])
    |> validate_inclusion(:status, ["ACTIVE"])
    |> cast_embed(:documents, with: &document_changeset/2)
    |> cast_embed(:addresses, with: &address_changeset/2)
    |> cast_embed(:phones, with: &phone_changeset/2)
    |> cast_embed(:emergency_contact, with: &emergency_contact_changeset/2)
    |> cast_embed(:confidant_person, with: &confidant_person_changeset/2)
  end

  def document_changeset(struct, params) do
    struct
    |> cast(params, @document_fields)
    |> validate_inclusion(:type, ["PASSPORT", "NATIONAL_ID", "BIRTH_CERTIFICATE", "TEMPORARY_CERTIFICATE"])
  end

  def address_changeset(struct, params) do
    struct
    |> cast(params, @address_fields)
    |> validate_inclusion(:type, ["RESIDENCE", "REGISTRATION"])
    |> validate_inclusion(:country, ["UA"])
    |> validate_inclusion(:city_type, ["CITY", "TOWN", "VILLAGE"])
  end

  def phone_changeset(struct, params) do
    struct
    |> cast(params, @phone_fields)
    |> validate_inclusion(:type, ["MOBILE", "LANDLINE"])
  end

  def emergency_contact_changeset(struct, params) do
    struct
    |> cast(params, @emergency_contact_fields)
    |> cast_embed(:phones, with: &phone_changeset/2)
  end

  def confidant_person_changeset(struct, params) do
    struct
    |> cast(params, @confidant_person_fields)
    |> validate_inclusion(:gender, ["MALE", "FEMALE"])
    |> cast_embed(:phones, with: &phone_changeset/2)
    |> cast_embed(:documents, with: &document_changeset/2)
  end

  def search(%Ecto.Changeset{changes: parameters}, params) do
    cursors =
      %Ecto.Paging.Cursors{
        starting_after: Map.get(params, "starting_after"),
        ending_before: Map.get(params, "ending_before", nil)
      }

    limit = Map.get(params, "limit", Confex.get(:mpi, :max_persons_result))

    parameters
    |> get_query()
    |> Repo.page(%Ecto.Paging{limit: limit, cursors: cursors})
  end

  def get_query(%{phone_number: phone_number} = changes) do
    params =
      changes
      |> Map.delete(:phone_number)
      |> Map.to_list()

    from s in MPI.Person,
      where: ^params,
      where: fragment("? @> ?", s.phones, ~s/[{"type":"MOBILE","number":"#{phone_number}"}]/)
  end

  def get_query(params) do
    params = Map.to_list(params)
    from s in MPI.Person,
      where: ^params
  end
end
