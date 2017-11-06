defmodule MPI.Repo.Migrations.RenameAuditLog do
  use Ecto.Migration

  def change do
    rename table("audit_log"), to: table("audit_log_mpi")
  end
end
