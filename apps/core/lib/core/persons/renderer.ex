defmodule Core.Persons.Renderer do
  @moduledoc false

  def render("person.json", person) do
    person
    |> Map.delete(:person_addresses)
    |> Map.merge(%{
      merged_ids: Map.get(person, :merged_ids, [])
    })
  end
end
