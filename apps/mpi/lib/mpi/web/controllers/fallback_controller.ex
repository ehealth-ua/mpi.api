defmodule MPI.Web.FallbackController do
  @moduledoc false

  use MPI.Web, :controller
  alias EView.Views.Error

  def call(conn, params) when is_nil(params) or params === [] do
    conn
    |> put_status(:not_found)
    |> render(EView.Views.Error, :"404")
  end

  def call(conn, %Ecto.Changeset{valid?: false} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.ValidationError, :"422", changeset)
  end

  def call(conn, {:error, %Ecto.Changeset{valid?: false} = changeset}) do
    call(conn, changeset)
  end

  def call(conn, {:error, {:"422", error}}) do
    conn
    |> put_status(422)
    |> render(Error, :"400", %{message: error})
  end

  def call(conn, {:validation_error, validation_errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.ValidationError, :"422", schema: validation_errors)
  end

  def call(conn, {:error, {:conflict, reason}}) do
    conn
    |> put_status(:conflict)
    |> render(EView.Views.Error, :"409", %{message: reason})
  end
end
