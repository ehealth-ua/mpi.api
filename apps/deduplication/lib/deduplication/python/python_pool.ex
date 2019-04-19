defmodule Deduplication.PythonPool do
  @moduledoc false

  use Agent
  use Confex, otp_app: :deduplication

  alias Deduplication.PythonWorker

  def start_link(_) do
    {:ok, _} =
      Supervisor.start_link([:poolboy.child_spec(:worker, poolboy_config())],
        strategy: :one_for_one,
        name: Deduplication.Supervisor.PythonPool
      )
  end

  defp poolboy_config do
    [
      {:name, {:local, :python_workers}},
      {:worker_module, PythonWorker},
      {:size, config()[:python_workers_pool_size]},
      {:max_overflow, 0}
    ]
  end
end
