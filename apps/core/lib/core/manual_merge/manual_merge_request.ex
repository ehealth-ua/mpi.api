defmodule Core.ManualMergeRequest do
  @moduledoc false

  use Ecto.Schema
  import Ecto.Changeset
  alias Core.ManualMergeCandidate
  alias Ecto.UUID

  @status_new "NEW"
  @status_split "SPLIT"
  @status_merge "MERGE"
  @status_trash "TRASH"
  @status_postpone "POSTPONE"

  @fields_required ~w(
    assignee_id
    manual_merge_candidate_id
  )a

  @fields_optional ~w(
    status
    comment
  )a

  @primary_key {:id, Ecto.UUID, autogenerate: true}
  @derive {Poison.Encoder, except: [:__meta__]}
  schema "manual_merge_requests" do
    field(:status, :string, default: @status_new)
    field(:comment, :string, default: nil)
    field(:assignee_id, UUID, default: nil)

    belongs_to(:manual_merge_candidate, ManualMergeCandidate, type: UUID)

    timestamps(type: :utc_datetime)
  end

  def changeset(%__MODULE__{} = merge_request, params) do
    merge_request
    |> cast(params, @fields_required ++ @fields_optional)
    |> validate_required(@fields_required)
  end

  def status(:new), do: @status_new
  def status(:split), do: @status_split
  def status(:merge), do: @status_merge
  def status(:trash), do: @status_trash
  def status(:postpone), do: @status_postpone
end
