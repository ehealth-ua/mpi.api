defmodule Core.PersonAuthenticationMethod do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.Person
  alias Ecto.Changeset

  @derive {Poison.Encoder, only: [:type, :phone_number]}
  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @foreign_key_type Ecto.UUID
  schema "person_authentication_methods" do
    field(:type, :string)
    field(:phone_number, :string)
    belongs_to(:person, Person)
    timestamps(type: :utc_datetime_usec)
  end

  @fields_required [:type]
  @fields_optional [:phone_number]

  def changeset(%__MODULE__{} = person_authentication_method, params \\ %{}) do
    person_authentication_method
    |> cast(params, @fields_required ++ @fields_optional)
    |> validate_required(@fields_required)
    |> validate_phone_number()
    |> unique_constraint(:type, name: :authentication_methods_uniq_index)
  end

  defp validate_phone_number(%Changeset{valid?: true, changes: %{type: "OTP", phone_number: _}} = changeset) do
    changeset
  end

  defp validate_phone_number(%Changeset{valid?: true, changes: %{type: "OTP"}} = changeset) do
    add_error(changeset, :phone_number, "can't be blank when type is 'OTP'", validation: :required)
  end

  defp validate_phone_number(changeset), do: changeset
end
