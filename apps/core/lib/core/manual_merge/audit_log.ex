defmodule Core.ManualMerge.AuditLog do
  @moduledoc """
  This is schema that used to store changes in DB.
  """
  use Ecto.Schema

  @primary_key {:id, :binary_id, autogenerate: true}
  schema "audit_log_deduplication" do
    field(:actor_id, :string)
    field(:resource, :string)
    field(:resource_id, :string)
    field(:changeset, :map)

    timestamps(type: :utc_datetime_usec, updated_at: false)
  end
end
