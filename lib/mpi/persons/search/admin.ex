defmodule MPI.Persons.Search.Admin do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  schema "persons" do
    field(:type, :string)
    field(:number, :string)
  end

  @fields_required ~w(type number)a

  def changeset(params) do
    %__MODULE__{}
    |> cast(params, @fields_required)
    |> validate_required(@fields_required)
  end
end
