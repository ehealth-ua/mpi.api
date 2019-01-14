defmodule Core.Person do
  @moduledoc false

  use Ecto.Schema
  alias Core.PersonAddress
  alias Core.PersonDocument
  alias Core.PersonPhone

  @status_active "active"
  @status_inactive "inactive"

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__, :person_addresses]}
  schema "persons" do
    field(:version, :string, default: "default")
    field(:first_name, :string)
    field(:last_name, :string)
    field(:second_name, :string)
    field(:birth_date, :date)
    field(:birth_country, :string)
    field(:birth_settlement, :string)
    field(:gender, :string)
    field(:email, :string)
    field(:tax_id, :string)
    field(:unzr, :string)
    field(:death_date, :date)
    field(:preferred_way_communication, :string)
    field(:invalid_tax_id, :boolean, default: false)
    field(:is_active, :boolean, default: true)
    field(:person_addresses, {:array, :map})
    field(:secret, :string)
    field(:emergency_contact, :map)
    field(:confidant_person, {:array, :map})
    field(:patient_signed, :boolean)
    field(:process_disclosure_data_consent, :boolean)
    field(:status, :string, default: @status_active)
    field(:inserted_by, :string)
    field(:updated_by, :string)
    field(:authentication_methods, {:array, :map})
    field(:merged_ids, {:array, :string})
    field(:no_tax_id, :boolean, default: false)

    has_many(:documents, PersonDocument, on_delete: :delete_all, on_replace: :delete)
    has_many(:phones, PersonPhone, on_delete: :delete_all, on_replace: :delete)
    has_many(:addresses, PersonAddress, on_delete: :delete_all, on_replace: :delete)
    timestamps(type: :utc_datetime)
  end

  def status(:active), do: @status_active
  def status(:inactive), do: @status_inactive

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
    unzr
    death_date
    preferred_way_communication
    invalid_tax_id
    is_active
    person_addresses
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
    no_tax_id
  )

  @fields_required [
    :version,
    :first_name,
    :last_name,
    :birth_date,
    :birth_country,
    :birth_settlement,
    :gender,
    :secret,
    :addresses,
    :authentication_methods,
    :emergency_contact,
    :patient_signed,
    :process_disclosure_data_consent,
    :status,
    :inserted_by,
    :updated_by
  ]

  def fields, do: @fields
  def fields_required, do: @fields_required
end
