defmodule MPI.Web.PersonController do
  @moduledoc false
  use MPI.Web, :controller
  alias MPI.Repo
  alias MPI.Person
  alias MPI.Persons.PersonsAPI
  alias MPI.Persons.PersonSearch
  alias Ecto.Changeset
  alias Scrivener.Page

  action_fallback MPI.Web.FallbackController

  @header_consumer_id "x-consumer-id"

  def index(conn, params) do
    with %Changeset{valid?: true} = changeset <- PersonSearch.changeset(params),
      %Page{total_pages: 1} = paging <- PersonsAPI.search(changeset, params) do
        conn
        |> put_status(:ok)
        |> render("persons.json", %{
          persons: paging.entries,
          paging: paging,
          search_params: changeset.changes
        })
    end
  end

  def all(conn, params) do
    with %Changeset{valid?: true} = changeset <- PersonSearch.changeset(params),
      %Page{total_pages: 1} = paging <- PersonsAPI.search(changeset, params, true) do
      conn
      |> put_status(:ok)
      |> render("persons.json", %{
        persons: paging.entries,
        paging: paging,
        search_params: changeset.changes
      })
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
    with search_params <- Map.take(params, ["last_name", "first_name", "birth_date", "tax_id", "second_name"]),
      %Changeset{valid?: true} = changeset <- PersonSearch.changeset(search_params),
      %Page{} = paging <- PersonsAPI.search(changeset, params) do
        create_person_strategy(paging, conn, params)
    end
  end

  def update(conn, %{"id" => id} = params) do
    with %Person{} = person <- Repo.get(Person, id),
      %Changeset{valid?: true} = changeset <- PersonsAPI.changeset(person, preprocess_params(person, params)),
      {:ok, %Person{} = person} <- Repo.update_and_log(changeset, get_consumer_id(conn.req_headers))  do
        conn
        |> put_status(:ok)
        |> render("person.json", %{person: person})
      end
  end

  defp create_person_strategy(%Page{entries: [person]}, conn, params) do
    with %Changeset{valid?: true} = changeset <- PersonsAPI.changeset(person, params),
      {:ok, %Person{} = updated_person} <- Repo.update_and_log(changeset, get_consumer_id(conn.req_headers)) do
        conn
        |> put_status(:ok)
        |> render("person.json", %{person: updated_person})
    end
  end

  # Case: No records found or found more than one
  # https://edenlab.atlassian.net/wiki/display/EH/Private.Create+or+update+Person
  defp create_person_strategy(%Page{}, conn, params) do
    with %Changeset{valid?: true} = changeset <- PersonsAPI.changeset(%Person{}, params),
      {:ok, person} <- Repo.insert_and_log(changeset, get_consumer_id(conn.req_headers)) do
        conn
        |> put_status(:created)
        |> render("person.json", %{person: person})
    end
  end

  defp preprocess_params(person, params) do
    existing_merged_ids = person.merged_ids || []
    new_merged_ids = Map.get(params, "merged_ids", [])

    Map.merge(params, %{"merged_ids" => existing_merged_ids ++ new_merged_ids})
  end

  def get_consumer_id(headers) do
    get_header(headers, @header_consumer_id)
  end

  def get_header(headers, header) when is_list(headers) do
    list = for {k, v} <- headers, k == header, do: v
    List.first(list)
  end
end
