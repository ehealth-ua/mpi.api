defmodule PersonUpdatesProducer.Application do
  @moduledoc false

  use Application
  use Confex, otp_app: :person_updates_producer
  alias PersonUpdatesProducer.Worker

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  def start(_type, _args) do
    import Supervisor.Spec

    children = if config()[:env] == :test, do: [], else: [worker(Worker, [], restart: :transient)]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: PersonUpdatesProducer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
