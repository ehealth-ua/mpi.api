defmodule Core.ReadRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :core, adapter: Ecto.Adapters.Postgres
  use EctoTrail

  alias Scrivener.Config

  @paginator_options [
    max_page_size: Confex.fetch_env!(:core, :max_page_size),
    page_size: Confex.fetch_env!(:core, :page_size)
  ]
  use Scrivener, @paginator_options

  def paginator_options(options \\ []) do
    Config.new(__MODULE__, @paginator_options, options)
  end
end
