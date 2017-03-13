defmodule Mpi.Web.FallbackController do
  @moduledoc false
  use Mpi.Web, :controller

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(EView.Views.PhoenixError, :"404")
  end
end
