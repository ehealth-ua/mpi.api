defmodule MPI.Person do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__]}
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
    field(:national_id, :string)
    field(:death_date, :date)
    field(:archived_at, :date)
    field(:preferred_way_communication, :string)
    field(:invalid_tax_id, :boolean, default: false)
    field(:is_active, :boolean, default: true)
    field(:documents, {:array, :map})
    field(:addresses, {:array, :map})
    field(:phones, {:array, :map})
    field(:secret, :string)
    field(:emergency_contact, :map)
    field(:confidant_person, {:array, :map})
    field(:patient_signed, :boolean)
    field(:process_disclosure_data_consent, :boolean)
    field(:status, :string, default: "active")
    field(:inserted_by, :string, default: "default")
    field(:updated_by, :string, default: "default")
    field(:authentication_methods, {:array, :map})
    field(:merged_ids, {:array, :string})

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
    archived_at
    preferred_way_communication
    invalid_tax_id
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

  @fields_required [
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

  def fields, do: @fields
  def fields_required, do: @fields_required
end
