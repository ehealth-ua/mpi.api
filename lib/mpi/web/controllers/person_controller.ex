defmodule MPI.Web.PersonController do
  @moduledoc false

  use MPI.Web, :controller
  alias Ecto.Changeset
  alias MPI.ConnUtils
  alias MPI.Person
  alias MPI.Persons.PersonsAPI
  alias MPI.Repo
  alias Scrivener.Page

  action_fallback(MPI.Web.FallbackController)

  @person_status_active Person.status(:active)

  def index(conn, params) do
    with %Page{} = paging <- PersonsAPI.search(params) do
      conn
      |> put_status(:ok)
      |> render("persons.json", %{
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
    with %Person{} = person <- PersonsAPI.get_by_id(id),
         :ok <- person_is_active(person),
         %Changeset{valid?: true} = changeset <- PersonsAPI.changeset(person, preprocess_params(person, params)),
         consumer_id = ConnUtils.get_consumer_id(conn),
         {:ok, %Person{} = person} <- Repo.update_and_log(changeset, consumer_id) do
      conn
      |> put_status(:ok)
      |> render("person.json", %{person: person})
    end
  end

  defp person_is_active(%Person{is_active: true}), do: :ok
  defp person_is_active(_), do: {:error, {:"422", "Person is not active"}}

  def reset_auth_method(conn, %{"id" => id}) do
    params = %{"authentication_methods" => [%{"type" => "NA"}]}

    with %Person{status: @person_status_active} = person <- PersonsAPI.get_by_id(id),
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
