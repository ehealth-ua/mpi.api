defmodule PersonDeactivator.Application do
  @moduledoc false
  import Supervisor.Spec
  use Application
  use Confex, otp_app: :person_deactivator

  alias PersonDeactivator.Worker

  def start(_type, _args) do
    children = if config(:env) == :test, do: [], else: [worker(Worker, [], restart: :transient)]

    opts = [strategy: :one_for_one, name: PersonDeactivator.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp config(key) when is_atom(key), do: config()[key]
end
