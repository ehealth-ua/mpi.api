defmodule MPI.Web.PersonView do
  @moduledoc false
  use MPI.Web, :view

  def render("person.json", %{person: %MPI.Person{} = person}) do
    convert_merged_ids(person)
  end

  def render("persons.json", %{persons: persons, search_params: %{ids: _}}) do
    Enum.map(persons, fn(person) ->
      Map.take(person, ~W(id first_name last_name second_name)a)
    end)
  end

  def render("persons.json", %{persons: persons, search_params: search_params}) do
    Enum.map(persons, fn(person) -> person_short(person, search_params) end)
  end

  defp person_short(person, params) do
    phones = Map.fetch!(person, :phones) || []
    phone_number =
      phones
      |> Enum.filter(fn(phone) -> phone["type"] == "MOBILE" end)
      |> get_phone_number()

    take_fields = Map.keys(params)

    person
    |> Map.take(take_fields ++ [:id, :history, :merged_ids, :birth_country, :birth_settlement])
    |> add_phone_number_to_map(phone_number, take_fields)
    |> convert_merged_ids()
  end

  defp get_phone_number([]), do: nil
  defp get_phone_number([%{"number" => number}]), do: number

  defp add_phone_number_to_map(map, phone_number, take_fields) do
    case Enum.member?(take_fields, :phone_number) do
      false -> map
      true -> Map.put(map, :phone_number, phone_number)
    end
  end

  defp convert_merged_ids(%{merged_ids: nil} = params), do: Map.put(params, :merged_ids, [])
  defp convert_merged_ids(params), do: params
end
