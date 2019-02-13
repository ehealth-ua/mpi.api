defmodule MPI.Web.PersonController do
  @moduledoc false

  use MPI.Web, :controller
  alias Core.Person
  alias Core.Persons.PersonsAPI
  alias MPI.ConnUtils
  alias MPI.Web.FallbackController
  alias MPI.Web.PersonView
  alias Scrivener.Page

  action_fallback(FallbackController)

  def index(conn, params) do
    with %Page{} = paging <- PersonsAPI.search(params) do
      conn
      |> put_status(:ok)
      |> put_view(PersonView)
      |> render("index.json", %{
        persons: paging.entries,
        paging: paging
      })
    else
      {:query_error, msg} ->
        conn
        |> put_status(:unprocessable_entity)
        |> put_resp_content_type("application/json")
        |> send_resp(422, Poison.encode!(%{error: msg}))

      error ->
        error
    end
  end

  def show(conn, %{"id" => id}) do
    with %Person{} = person <- PersonsAPI.get_by_id(id) do
      conn
      |> put_status(:ok)
      |> put_view(PersonView)
      |> render("show.json", %{person: person})
    end
  end

  def create(conn, params) do
    with {status, {:ok, %Person{} = person}} <- PersonsAPI.create(params, ConnUtils.get_consumer_id(conn)) do
      conn
      |> put_status(status)
      |> put_view(PersonView)
      |> render("show.json", %{person: person})
    end
  end

  def update(conn, %{"id" => id} = params) do
    consumer_id = ConnUtils.get_consumer_id(conn)

    with {:ok, %Person{} = person} <- PersonsAPI.update(id, params, consumer_id) do
      conn
      |> put_status(:ok)
      |> put_view(PersonView)
      |> render("show.json", %{person: person})
    end
  end

  def reset_auth_method(conn, %{"id" => id}) do
    params = %{"authentication_methods" => [%{"type" => "NA"}]}
    consumer_id = ConnUtils.get_consumer_id(conn)

    with {:ok, person} <- PersonsAPI.reset_auth_method(id, params, consumer_id) do
      conn
      |> put_status(:ok)
      |> put_view(PersonView)
      |> render("show.json", %{person: person})
    end
  end
end
