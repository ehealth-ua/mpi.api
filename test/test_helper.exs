{:ok, _} = Application.ensure_all_started(:ex_machina)

Ecto.Adapters.SQL.Sandbox.mode(Mpi.Repo, :manual)

ExUnit.start()
