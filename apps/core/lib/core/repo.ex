defmodule Core.Repo do
  @moduledoc false
  @max_page_size 500
  def max_page_size, do: @max_page_size

  use Ecto.Repo, otp_app: :core, adapter: Ecto.Adapters.Postgres
  use Scrivener, page_size: 50, max_page_size: @max_page_size, options: [allow_overflow_page_number: true]
  use EctoTrail
end
