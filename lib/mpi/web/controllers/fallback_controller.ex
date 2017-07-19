defmodule MPI.Web.FallbackController do
  @moduledoc false
  use MPI.Web, :controller

  def call(conn, nil) do
    conn
    |> put_status(:not_found)
    |> render(EView.Views.Error, :"404")
  end

  def call(conn, {_data, %Ecto.Paging{has_more: true}}) do
    forbidden_message
      = "This API method returns only exact match results, please retry with more specific search parameters"
    conn
    |> put_status(:forbidden)
    |> render(EView.Views.PhoenixError, :"403", %{message: forbidden_message})
  end

  def call(conn, []) do
    conn
    |> put_status(:not_found)
    |> render(EView.Views.Error, :"404")
  end

  def call(conn, %Ecto.Changeset{valid?: false, data: %MPI.Persons.PersonSearch{}} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.ValidationError, :"422.query", changeset)
  end

  def call(conn, %Ecto.Changeset{valid?: false} = changeset) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.ValidationError, :"422", changeset)
  end

  def call(conn, {:validation_error, validation_errors}) do
    conn
    |> put_status(:unprocessable_entity)
    |> render(EView.Views.ValidationError, :"422", schema: validation_errors)
  end
end
