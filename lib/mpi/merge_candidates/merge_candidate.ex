defmodule MPI.MergeCandidate do
  @moduledoc false
  use Ecto.Schema

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "merge_candidates" do
    field :status, :string, default: "NEW"

    belongs_to :person, MPI.Person, foreign_key: :person_id, type: Ecto.UUID
    belongs_to :master_person, MPI.Person, foreign_key: :master_person_id, type: Ecto.UUID

    timestamps(type: :utc_datetime)
  end
end
