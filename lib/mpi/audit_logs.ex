defmodule MPI.AuditLogs do
  @moduledoc false

  alias EctoTrail.Changelog
  alias MPI.Repo

  def create_audit_logs(attrs_list \\ []) when is_list(attrs_list) do
    changes = Enum.map(attrs_list, &Map.put(&1, :inserted_at, DateTime.utc_now()))

    Repo.insert_all(Changelog, changes, returning: true)
  end
end
