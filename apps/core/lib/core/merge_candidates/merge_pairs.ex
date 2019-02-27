defmodule Core.MergedPair do
  @moduledoc false

  use Ecto.Schema
  alias Core.Person
  alias Ecto.UUID

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "merged_pairs" do
    belongs_to(:person, Person, foreign_key: :merge_person_id, type: UUID)
    belongs_to(:master_person, Person, foreign_key: :master_person_id, type: UUID)
    timestamps(type: :utc_datetime)
  end
end
