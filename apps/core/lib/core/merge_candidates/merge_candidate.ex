defmodule Core.MergeCandidate do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset

  alias Core.Person
  alias Ecto.UUID

  @new "NEW"
  @in_process "IN_PROCESS"
  @deactivate_ready "DECLARATION_READY_DEACTIVATE"
  @stale "STALE"
  @declined "DECLINED"
  @merged "MERGED"

  def status(:new), do: @new
  def status(:in_process), do: @in_process
  def status(:stale), do: @stale
  def status(:declined), do: @declined
  def status(:deactivate_ready), do: @deactivate_ready
  def status(:merged), do: @merged

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  schema "merge_candidates" do
    field(:status, :string, default: "NEW")
    field(:config, :map)
    field(:details, :map)
    field(:score, :float)

    belongs_to(:person, Person, foreign_key: :person_id, type: UUID)
    belongs_to(:master_person, Person, foreign_key: :master_person_id, type: UUID)
    timestamps(type: :utc_datetime_usec)
  end

  def changeset(%__MODULE__{} = merge_candidate, params) do
    cast(merge_candidate, params, [:status])
  end
end
