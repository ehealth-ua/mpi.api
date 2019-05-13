defmodule MPI.Web.FallbackController do
  @moduledoc false

  use MPI.Web, :controller
  alias EView.Views.{Error, ValidationError}

  def call(conn, params) when is_nil(params) or params === [] do
    conn
    |> put_status(:not_found)
    |> put_view(Error)
    |> render(:"404")
  end

  def call(conn, %Ecto.Changeset{valid?: false} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(ValidationError)
    |> render(:"422", changeset)
  end

  def call(conn, {:error, %Ecto.Changeset{valid?: false} = changeset}) do
    call(conn, changeset)
  end

  def call(conn, {:error, {:"422", error}}) do
    conn
    |> put_status(422)
    |> put_view(Error)
    |> render(:"400", %{message: error})
  end

  def call(conn, {:validation_error, validation_errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> put_view(Error)
    |> render(:"422", schema: validation_errors)
  end

  def call(conn, {:error, {:conflict, reason}}) do
    conn
    |> put_status(:conflict)
    |> put_view(Error)
    |> render(:"409", %{message: reason})
  end

  def call(conn, {:error, :has_already_been_taken}) do
    conn
    |> put_status(:conflict)
    |> put_view(Error)
    |> render(:"409", %{message: "Such person already exists"})
  end
end
