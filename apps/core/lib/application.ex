defmodule Core.Application do
  @moduledoc false

  use Application
  alias Core.DeduplicationRepo
  alias Core.ReadRepo
  alias Core.Repo
  alias Core.TelemetryHandler.DeduplicationRepoHandler
  alias Core.TelemetryHandler.ReadRepoHandler
  alias Core.TelemetryHandler.RepoHandler

  def start(_type, _args) do
    :telemetry.attach("log-handler", [:core, :repo, :query], &RepoHandler.handle_event/4, nil)
    :telemetry.attach("log-read-handler", [:core, :read_repo, :query], &ReadRepoHandler.handle_event/4, nil)

    :telemetry.attach(
      "log-deduplication-handler",
      [:core, :deduplication_repo, :query],
      &DeduplicationRepoHandler.handle_event/4,
      nil
    )

    children = [
      {Repo, []},
      {ReadRepo, []},
      {DeduplicationRepo, []}
    ]

    opts = [strategy: :one_for_one, name: Core.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
