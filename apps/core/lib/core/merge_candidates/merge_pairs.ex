defmodule Core.MergedPair do
  @moduledoc false
  import Ecto.Changeset
  use Ecto.Schema
  alias Core.Person
  alias Ecto.UUID

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "merged_pairs" do
    belongs_to(:person, Person, foreign_key: :merge_person_id, type: UUID)
    belongs_to(:master_person, Person, foreign_key: :master_person_id, type: UUID)
    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = merge_pair, params) do
    cast(merge_pair, params, [:master_person_id, :merge_person_id])
  end
end
