defmodule MPI do
  @moduledoc false

  use Application
  alias MPI.Web.Endpoint

  def start(_type, _args) do
    import Supervisor.Spec

    children = [
      supervisor(Endpoint, [])
    ]

    opts = [strategy: :one_for_one, name: MPI.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
