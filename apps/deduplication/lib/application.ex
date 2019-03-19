defmodule Deduplication.Application do
  @moduledoc false

  use Application
  alias Deduplication.DeduplicationPool
  alias Deduplication.PythonPool

  def start(_type, _args) do
    {:ok, _} =
      Supervisor.start_link(
        [
          {DeduplicationPool, []},
          {PythonPool, []}
        ],
        strategy: :one_for_one,
        name: Deduplication.Supervisor
      )
  end
end
