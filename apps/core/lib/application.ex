defmodule Core.Application do
  @moduledoc false

  use Application
  alias Core.DeduplicationRepo
  alias Core.Repo
  alias Core.TelemetryHandler.DeduplicationRepoHandler
  alias Core.TelemetryHandler.RepoHandler

  def start(_type, _args) do
    :telemetry.attach("log-handler", [:core, :repo, :query], &RepoHandler.handle_event/4, nil)

    :telemetry.attach(
      "log-deduplication-handler",
      [:core, :read_repo, :query],
      &DeduplicationRepoHandler.handle_event/4,
      nil
    )

    children = [
      {Repo, []},
      {DeduplicationRepo, []}
    ]

    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
