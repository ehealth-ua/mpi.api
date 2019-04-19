defmodule Deduplication.Application do
  @moduledoc false

  use Application
  alias Deduplication.DeduplicationPool
  alias Deduplication.PythonPool
  alias Deduplication.Scheduler

  def start(_type, _args) do
    env = Application.get_env(:deduplication, __MODULE__)[:env]

    children = [
      {DeduplicationPool, [env]},
      {PythonPool, []},
      {Scheduler, []}
    ]

    result = Supervisor.start_link(children, strategy: :one_for_one, name: Deduplication.Supervisor)
    if env != :test, do: Scheduler.create_job()
    result
  end
end
