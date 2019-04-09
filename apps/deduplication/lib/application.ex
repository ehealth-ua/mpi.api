defmodule Deduplication.Application do
  @moduledoc false

  use Application
  alias Deduplication.DeduplicationPool
  alias Deduplication.PythonPool
  alias Deduplication.Sheduler

  def start(_type, _args) do
    if config(:env) == :test do
      start_deduplication()
    else
      result = Supervisor.start_link([{Sheduler, []}], strategy: :one_for_one, name: Deduplication.ShedulerSupervisor)
      Sheduler.create_job(&start_deduplication/0)
      result
    end
  end

  defp start_deduplication do
    if Process.whereis(Deduplication.Supervisor), do: Supervisor.stop(Deduplication.Supervisor)

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

  defp config(key) when is_atom(key), do: Application.get_env(:deduplication, __MODULE__)[key]
end
