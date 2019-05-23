defmodule Core.Person do
  @moduledoc false

  use Ecto.Schema
  alias Core.MergedPair
  alias Core.PersonAddress
  alias Core.PersonAuthenticationMethod
  alias Core.PersonDocument
  alias Core.PersonPhone

  @status_active "active"
  @status_inactive "inactive"

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
    field(:unzr, :string)
    field(:death_date, :date)
    field(:preferred_way_communication, :string)
    field(:invalid_tax_id, :boolean, default: false)
    field(:is_active, :boolean, default: true)
    field(:secret, :string)
    field(:emergency_contact, :map)
    field(:confidant_person, {:array, :map})
    field(:patient_signed, :boolean)
    field(:process_disclosure_data_consent, :boolean)
    field(:status, :string, default: @status_active)
    field(:inserted_by, :string)
    field(:updated_by, :string)
    field(:authentication_methods, {:array, :map})
    field(:no_tax_id, :boolean, default: false)

    has_many(:documents, PersonDocument, on_delete: :delete_all, on_replace: :delete)
    has_many(:phones, PersonPhone, on_delete: :delete_all, on_replace: :delete)
    has_many(:addresses, PersonAddress, on_delete: :delete_all, on_replace: :delete)
    has_many(:merged_persons, MergedPair, foreign_key: :master_person_id, on_delete: :delete_all, on_replace: :delete)
    has_one(:master_person, MergedPair, foreign_key: :merge_person_id, on_delete: :delete_all, on_replace: :delete)
    has_many(:person_authentication_methods, PersonAuthenticationMethod, on_delete: :delete_all, on_replace: :delete)
    timestamps(type: :utc_datetime_usec)
  end

  def status(:active), do: @status_active
  def status(:inactive), do: @status_inactive

  @fields ~w(
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
    secret
    emergency_contact
    confidant_person
    patient_signed
    process_disclosure_data_consent
    status
    inserted_by
    updated_by
    authentication_methods
    no_tax_id
  )a

  @fields_required ~w(
    version
    first_name
    last_name
    birth_date
    birth_country
    birth_settlement
    gender
    secret
    authentication_methods
    emergency_contact
    patient_signed
    process_disclosure_data_consent
    status
    inserted_by
    updated_by
  )a

  @preload_fields ~w(documents phones addresses merged_persons master_person person_authentication_methods)a

  def fields, do: @fields
  def fields_required, do: @fields_required
  def preload_fields, do: @preload_fields
end
