defmodule Core.DeduplicationRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :core
  use Scrivener, page_size: 50, max_page_size: 500
  use EctoTrail

  def set_runtime_params(conn) do
    config = Confex.get_env(@otp_app, __MODULE__, [])
    params = Keyword.get(config, :runtime_params, [])

    do_set_runtime_params(conn, params)
  end

  defp do_set_runtime_params(_, []), do: :ok

  defp do_set_runtime_params(conn, [{name, value} | tail]) do
    Postgrex.query!(conn, "SELECT set_config($1, $2, false)", [name, value])
    do_set_runtime_params(conn, tail)
  end
end
