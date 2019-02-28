defmodule Core.MergeCandidate do
  @moduledoc false

  use Ecto.Schema
  alias Core.Person
  alias Ecto.UUID

  @new "NEW"
  @in_process "IN_PROCESS"
  @merged "MERGED"

  def status(:new), do: @new
  def status(:in_process), do: @in_process
  def status(:merged), do: @merged

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "merge_candidates" do
    field(:status, :string, default: "NEW")
    field(:config, :map)
    field(:details, :map)
    field(:score, :float)

    belongs_to(:person, Person, foreign_key: :person_id, type: UUID)
    belongs_to(:master_person, Person, foreign_key: :master_person_id, type: UUID)
    timestamps(type: :utc_datetime)
  end
end
