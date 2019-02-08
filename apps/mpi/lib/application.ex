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

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  def config_change(changed, _new, removed) do
    Endpoint.config_change(changed, removed)
    :ok
  end
end
