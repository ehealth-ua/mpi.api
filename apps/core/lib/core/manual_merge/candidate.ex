defmodule Core.ManualMergeCandidate do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.ManualMergeRequest
  alias Core.MergeCandidate
  alias Ecto.UUID

  @status_new "NEW"
  @status_processed "PROCESSED"

  @status_reason_auto_merge "AUTO-MERGE"

  @decision_split "SPLIT"
  @decision_merge "MERGE"
  @decision_trash "TRASH"

  @fields_required ~w(
    person_id
    master_person_id
    merge_candidate_id
  )a

  @fields_optional ~w(
    status
    decision
    assignee_id
  )a

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "manual_merge_candidates" do
    field(:status, :string, default: @status_new)
    field(:status_reason, :string, default: @status_new)
    field(:decision, :string, default: nil)
    field(:assignee_id, UUID, default: nil)
    field(:person_id, UUID)
    field(:master_person_id, UUID)

    has_many(:manual_merge_requests, ManualMergeRequest, foreign_key: :manual_merge_candidate_id)
    # Refers to MPI db
    belongs_to(:merge_candidate, MergeCandidate, type: UUID)

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = merge_request, params) do
    merge_request
    |> cast(params, @fields_required ++ @fields_optional)
    |> validate_required(@fields_required)
  end

  def status(:new), do: @status_new
  def status(:processed), do: @status_processed

  def status_reason(:auto_merge), do: @status_reason_auto_merge

  def decision(:split), do: @decision_split
  def decision(:merge), do: @decision_merge
  def decision(:trash), do: @decision_trash
end
