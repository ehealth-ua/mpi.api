defmodule Core.AuditLogs do
  @moduledoc false

  alias Core.DeduplicationRepo
  alias Core.ManualMerge.AuditLog
  alias Core.Repo
  alias EctoTrail.Changelog

  def create_audit_logs(attrs_list \\ []), do: create_audit_logs(:mpi, attrs_list)

  def create_audit_logs(:mpi, attrs_list) when is_list(attrs_list) do
    changes = Enum.map(attrs_list, &Map.put(&1, :inserted_at, DateTime.utc_now()))
    Repo.insert_all(Changelog, changes, returning: true)
  end

  def create_audit_logs(:deduplication, attrs_list) when is_list(attrs_list) do
    changes = Enum.map(attrs_list, &Map.put(&1, :inserted_at, DateTime.utc_now()))
    DeduplicationRepo.insert_all(AuditLog, changes, returning: true)
  end
end
