defmodule Core.ReadRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :core, adapter: Ecto.Adapters.Postgres
  use Scrivener, page_size: 50, max_page_size: 500, options: [allow_overflow_page_number: true]
  use EctoTrail
end