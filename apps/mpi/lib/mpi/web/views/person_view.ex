defmodule MPI.Web.PersonView do
  @moduledoc false

  use MPI.Web, :view
  alias Core.Person
  alias Core.Persons.Renderer

  def render("person.json", %{person: %Person{} = person}) do
    Renderer.render("person.json", person)
  end

  def render("persons.json", %{persons: persons}) do
    render_many(persons, __MODULE__, "person.json", as: :person)
  end
end
