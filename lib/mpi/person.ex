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
    field :birth_country, :string
    field :birth_settlement, :string
    field :gender, :string
    field :email, :string
    field :tax_id, :string
    field :national_id, :string
    field :death_date, :date
    field :is_active, :boolean, default: true
    field :documents, {:array, :map}
    field :addresses, {:array, :map}
    field :phones, {:array, :map}
    field :secret, :string
    field :emergency_contact, :map
    field :confidant_person, {:array, :map}
    field :patient_signed, :boolean
    field :process_disclosure_data_consent, :boolean
    field :status, :string, default: "active"
    field :inserted_by, :string, default: "default"
    field :updated_by, :string, default: "default"
    field :authentication_methods, {:array, :map}
    field :merged_ids, {:array, :uuid}

    timestamps(type: :utc_datetime)
  end

  @fields ~W(
    version
    first_name
    last_name
    second_name
    birth_date
    birth_country
    birth_settlement
    gender
    email
    tax_id
    national_id
    death_date
    is_active
    documents
    addresses
    phones
    secret
    emergency_contact
    confidant_person
    patient_signed
    process_disclosure_data_consent
    status
    inserted_by
    updated_by
    authentication_methods
    merged_ids
  )

  @required_fields [
    :version,
    :first_name,
    :last_name,
    :birth_date,
    :birth_country,
    :birth_settlement,
    :gender,
    :secret,
    :documents,
    :addresses,
    :authentication_methods,
    :emergency_contact,
    :patient_signed,
    :process_disclosure_data_consent,
    :status,
    :inserted_by,
    :updated_by
  ]

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, @fields)
    |> validate_required(@required_fields)
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
