defmodule MPI.PersonSearchChangeset do
  @moduledoc false
  use Ecto.Schema

  import Ecto.Changeset

  alias EView.Changeset.Validators.PhoneNumber
  alias MPI.PersonSearchChangeset

  schema "persons" do
    field :first_name, :string
    field :last_name, :string
    field :second_name, :string
    field :birth_date, :utc_datetime
    field :tax_id, :string
    field :phone_number, :string
  end

  @fields ~W(
    first_name
    last_name
    second_name
    birth_date
    tax_id
    phone_number
  )

  @required_fields [
    :first_name,
    :last_name,
    :birth_date,
  ]

  def changeset(params \\ %{}) do
    %PersonSearchChangeset{}
    |> cast(params, @fields)
    |> validate_required(@required_fields)
    |> PhoneNumber.validate_phone_number(:phone_number)
  end
end
