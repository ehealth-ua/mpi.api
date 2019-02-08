defmodule PersonUpdatesProducer.Application do
  @moduledoc false

  use Application
  use Confex, otp_app: :person_updates_producer
  alias PersonUpdatesProducer.Worker

  def start(_type, _args) do
    import Supervisor.Spec
    opts = [strategy: :one_for_one, name: PersonUpdatesProducer.Supervisor]
    result = Supervisor.start_link([{Worker, []}], opts)
    Worker.create_jobs()
    result
  end
end
