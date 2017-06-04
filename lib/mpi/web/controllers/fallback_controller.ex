defmodule MPI.Web.FallbackController do
  @moduledoc false
  use MPI.Web, :controller

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(EView.Views.Error, :"404")
  end

  def call(conn, {_data, %Ecto.Paging{has_more: true}})do
    forbidden_message
      = "This API method returns only exact match results, please retry with more specific search result"
    conn
    |> put_status(:forbidden)
    |> render(EView.Views.PhoenixError, :"403", %{message: forbidden_message})
  end

  def call(conn, []) do
    conn
    |> put_status(:not_found)
    |> render(EView.Views.Error, :"404")
  end

  def call(conn, %Ecto.Changeset{valid?: false, data: %MPI.PersonSearchChangeset{}} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.ValidationError, :"422.query", changeset)
  end

  def call(conn, %Ecto.Changeset{valid?: false} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.ValidationError, :"422", changeset)
  end
end
