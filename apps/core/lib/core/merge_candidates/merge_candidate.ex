defmodule Core.MergeCandidate do
  @moduledoc false

  use Ecto.Schema
  alias Core.Person
  alias Ecto.UUID

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "merge_candidates" do
    field(:status, :string, default: "NEW")
    field(:config, :map)
    field(:details, :map)

    belongs_to(:person, Person, foreign_key: :person_id, type: UUID)
    belongs_to(:master_person, Person, foreign_key: :master_person_id, type: UUID)

    timestamps(type: :utc_datetime)
  end
end
