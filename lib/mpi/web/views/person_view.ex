defmodule MPI.Web.PersonView do
  @moduledoc false
  use MPI.Web, :view

  def render("person.json", %{person: %MPI.Person{} = person}) do
    # Temporary solution for BETA.
    Map.put(person, :confident_persons, [])
  end

  def render("persons.json", %{persons: persons}) do
    Enum.map(persons, fn(person) -> Map.take(person, [:id, :birth_place, :history]) end)
  end
end
