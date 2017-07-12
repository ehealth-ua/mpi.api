defmodule MPI.Web.PersonController do
  @moduledoc false
  use MPI.Web, :controller
  use JValid
  alias MPI.Repo
  alias MPI.Person
  alias MPI.PersonSearchChangeset
  alias Ecto.Changeset

  action_fallback MPI.Web.FallbackController

  use_schema :person, "specs/json_schemas/person_schema.json"

  def index(conn, params) do
    with %Changeset{valid?: true} = changeset <- PersonSearchChangeset.changeset(params),
      {persons, %Ecto.Paging{has_more: false} = paging} <- Person.search(changeset, params) do
        conn
        |> put_status(:ok)
        |> render("persons.json", %{persons: persons, paging: paging, search_params: changeset})
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
    case validate_schema(:person, params) do
      :ok -> with search_params <- Map.take(params, ["last_name", "first_name", "birth_date", "tax_id", "second_name"]),
        %Changeset{valid?: true} = changeset <- PersonSearchChangeset.changeset(search_params),
        {persons, paging} <- Person.search(changeset, params) do
          create_person_strategy({persons, paging}, conn, params)
      end
      {:error, errors} -> {:validation_error, errors}
    end
  end

  def update(conn, %{"id" => id} = params) do
    with %Person{} = person <- Repo.get(Person, id),
      %Changeset{valid?: true} = changeset <- Person.changeset(person, params),
      {:ok, %Person{} = person} <- Repo.update(changeset)  do
        conn
        |> put_status(:ok)
        |> render("person.json", %{person: person})
      end
  end

  defp create_person_strategy({[person], _paging}, conn, params) do
    with %Changeset{valid?: true} = changeset <- Person.changeset(person, params),
      {:ok, %Person{} = updated_person} <- Repo.update(changeset) do
        conn
        |> put_status(:ok)
        |> render("person.json", %{person: updated_person})
    end
  end

  @doc """
    Case: No records found or found more than one
    https://edenlab.atlassian.net/wiki/display/EH/Private.Create+or+update+Person
  """
  defp create_person_strategy({_persons, _paging}, conn, params) do
    with %Changeset{valid?: true} = changeset <- Person.changeset(%Person{}, params),
      {:ok, person} <- Repo.insert(changeset) do
        conn
        |> put_status(:created)
        |> render("person.json", %{person: person})
    end
  end
end
