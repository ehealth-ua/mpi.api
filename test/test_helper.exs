{:ok, _} = Application.ensure_all_started(:ex_machina)
{:ok, _} = Application.ensure_all_started(:mox)

Ecto.Adapters.SQL.Sandbox.mode(MPI.Repo, :manual)

ExUnit.start()

Mox.defmock(DeduplicationClientMock, for: MPI.Deduplication.DeduplicationClientBehaviour)
