defmodule PersonDeactivator.Application do
  @moduledoc false
  use Application

  alias Kaffe.Consumer

  def start(_type, _args) do
    Application.put_env(:kaffe, :consumer, Application.get_env(:person_deactivator, :kaffe_consumer))

    children = [
      %{
        id: Consumer,
        start: {Consumer, :start_link, []}
      }
    ]

    opts = [strategy: :one_for_one, name: PersonDeactivator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
