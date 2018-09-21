defmodule Core.AuditLogs do
  @moduledoc false

  alias Core.Repo
  alias EctoTrail.Changelog

  def create_audit_logs(attrs_list \\ []) when is_list(attrs_list) do
    changes = Enum.map(attrs_list, &Map.put(&1, :inserted_at, DateTime.utc_now()))
    Repo.insert_all(Changelog, changes, returning: true)
  end
end
