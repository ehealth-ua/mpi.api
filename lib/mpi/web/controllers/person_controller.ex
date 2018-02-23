defmodule MPI.Web.PersonController do
  @moduledoc false
  use MPI.Web, :controller
  alias MPI.Repo
  alias MPI.Person
  alias MPI.Persons.PersonsAPI
  alias Ecto.Changeset
  alias Scrivener.Page
  alias MPI.ConnUtils

  action_fallback(MPI.Web.FallbackController)

  def index(conn, params) do
    with %{changes: changes, paging: %Page{total_pages: 1} = paging} <- PersonsAPI.search(params, :public) do
      conn
      |> put_status(:ok)
      |> render("persons.json", %{
        persons: paging.entries,
        paging: paging,
        search_params: changes
      })
    end
  end

  def all(conn, params) do
    with %{changes: changes, paging: %Page{total_pages: 1} = paging} <- PersonsAPI.search(params, :public_all) do
      conn
      |> put_status(:ok)
      |> render("persons.json", %{
        persons: paging.entries,
        paging: paging,
        search_params: changes
      })
    end
  end

  def internal(conn, params) do
    with %{changes: changes, paging: %Page{} = paging} <- PersonsAPI.search(params, :admin) do
      conn
      |> put_status(:ok)
      |> render("persons.json", %{persons: paging.entries, paging: paging, search_params: changes})
    end
  end

  def show(conn, %{"id" => id}) do
    with %Person{} = person <- Repo.get(Person, id) do
      conn
      |> put_status(:ok)
      |> render("person.json", %{person: person})
    end
  end

  def create(conn, params) do
    with {status, {:ok, %Person{} = person}} <- PersonsAPI.create(params, ConnUtils.get_consumer_id(conn)) do
      conn
      |> put_status(status)
      |> render("person.json", %{person: person})
    end
  end

  def update(conn, %{"id" => id} = params) do
    with %Person{} = person <- Repo.get(Person, id),
         %Changeset{valid?: true} = changeset <- PersonsAPI.changeset(person, preprocess_params(person, params)),
         consumer_id = ConnUtils.get_consumer_id(conn),
         {:ok, %Person{} = person} <- Repo.update_and_log(changeset, consumer_id) do
      conn
      |> put_status(:ok)
      |> render("person.json", %{person: person})
    end
  end

  def reset_auth_method(conn, %{"id" => id}) do
    params = %{"authentication_methods" => [%{"type" => "NA"}]}

    with %Person{status: "active"} = person <- Repo.get(Person, id),
         %Changeset{valid?: true} = changeset <- PersonsAPI.changeset(person, params),
         consumer_id = ConnUtils.get_consumer_id(conn),
         {:ok, %Person{} = person} <- Repo.update_and_log(changeset, consumer_id) do
      conn
      |> put_status(:ok)
      |> render("person.json", %{person: person})
    else
      %Person{} -> {:error, {:conflict, "Invalid status MPI for this action"}}
      err -> err
    end
  end

  defp preprocess_params(person, params) do
    existing_merged_ids = person.merged_ids || []
    new_merged_ids = Map.get(params, "merged_ids", [])

    Map.merge(params, %{"merged_ids" => existing_merged_ids ++ new_merged_ids})
  end
end
