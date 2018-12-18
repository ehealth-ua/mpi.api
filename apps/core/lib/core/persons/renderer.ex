defmodule Core.Persons.Renderer do
  @moduledoc false

  def render("person.json", person) do
    Map.merge(person, %{
      merged_ids: Map.get(person, :merged_ids, []),
      addresses: Map.get(person, :addresses, []) ++ Map.get(person, :person_addresses, [])
    })
  end
end
