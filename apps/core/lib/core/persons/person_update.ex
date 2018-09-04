defmodule Core.PersonUpdate do
  @moduledoc false

  use Ecto.Schema

  schema "person_updates" do
    field(:person_id, Ecto.UUID)
    field(:updated_by, Ecto.UUID)
    field(:updated_at, :utc_datetime)
    field(:status, :string)
  end
end
