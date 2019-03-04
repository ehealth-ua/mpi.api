defmodule Core.VerifiedTs do
  @moduledoc """
  Table verified_ts has only one row stores minimum inserted_at of verified persons.
  This table exists in postgres instead of one record in memory or mnesia because of
  deployment perspective. We do not get min inserted_at join on merge candidates, because a lot of records could have no merge candidates
  """
  use Ecto.Schema

  schema "verified_ts" do
    timestamps(type: :utc_datetime)
  end
end

defmodule Core.VerifyingId do
  @moduledoc """
  Table verifying_ids store ids of checking persons, to be sure after deduplication were no fail one of process
  in parallel execution while processes with latest persons were success. Implementation of more safe execution makes process of deduplication too slow
  """

  import Ecto.Changeset
  use Ecto.Schema

  @primary_key {:id, Ecto.UUID, autogenerate: false}
  schema "verifying_ids" do
    field(:is_complete, :boolean)
  end

  def changeset(%__MODULE__{} = verifying_id, params) do
    cast(verifying_id, params, [:is_complete])
  end
end
