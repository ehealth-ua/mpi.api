defmodule Core.Application do
  @moduledoc false

  use Application
  alias Core.Repo
  import Supervisor.Spec, warn: false

  def start(_type, _args) do
    children = [
      supervisor(Repo, [])
    ]

    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
