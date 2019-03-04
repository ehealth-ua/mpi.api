defmodule Core.Application do
  @moduledoc false

  use Application
  import Supervisor.Spec, warn: false
  alias Core.DeduplicationRepo
  alias Core.Repo

  def start(_type, _args) do
    children = [
      Repo,
      DeduplicationRepo
    ]

    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
