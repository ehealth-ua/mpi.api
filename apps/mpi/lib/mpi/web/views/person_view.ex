defmodule MPI.Web.PersonView do
  @moduledoc false

  use MPI.Web, :view
  alias Core.Person
  alias Core.PersonAddress
  alias Core.PersonAuthenticationMethod
  alias Core.PersonDocument
  alias Core.PersonPhone

  def render("index.json", %{persons: persons}) do
    render_many(persons, __MODULE__, "show.json", as: :person)
  end

  def render("person_short.json", %{person: %{} = person, fields: fields}) do
    response =
      person
      |> Map.take(List.delete(fields, :phones))
      |> Map.delete(:authentication_methods)

    if :phones in fields do
      Map.put(response, :phones, render("person_phones.json", person))
    else
      response
    end
  end

  def render("show.json", %{person: %Person{} = person}) do
    person
    |> Map.take(extended_field(Person.fields()))
    |> Map.delete(:authentication_methods)
    |> Map.merge(%{
      merged_persons: render("merged_persons.json", person),
      master_person: render("master_person.json", person),
      documents: render("person_documents.json", person),
      phones: render("person_phones.json", person),
      addresses: render("person_address.json", person),
      authentication_methods: render("person_authentication_methods.json", person)
    })
  end

  def render("master_person.json", %{id: person_id, master_person: %{master_person_id: _} = master_person}) do
    master_person
    |> Map.take(extended_field([:master_person_id]))
    |> Map.put(:person_id, person_id)
  end

  def render("master_person.json", _), do: nil

  def render("merged_persons.json", %{id: person_id, merged_persons: [_ | _] = merged_persons}) do
    Enum.map(merged_persons, fn merged_person ->
      merged_person
      |> Map.take(extended_field([:merge_person_id]))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("merged_persons.json", _), do: []

  def render("person_documents.json", %{id: person_id, documents: [_ | _] = documents}) do
    Enum.map(documents, fn document ->
      document
      |> Map.take(extended_field(PersonDocument.fields()))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("person_documents.json", _), do: []

  def render("person_phones.json", %{id: person_id, phones: phones}) do
    Enum.map(phones, fn phone ->
      phone
      |> Map.take(extended_field(PersonPhone.fields()))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("person_phones.json", _), do: []

  def render("person_address.json", %{id: person_id, addresses: addresses}) do
    Enum.map(addresses, fn address ->
      address
      |> Map.take(extended_field(PersonAddress.fields()))
      |> Map.put(:person_id, person_id)
    end)
  end

  def render("person_address.json", _), do: []

  def render("person_authentication_methods.json", %{
        authentication_methods: authentication_methods,
        person_authentication_methods: person_authentication_methods
      })
      when is_nil(person_authentication_methods) or person_authentication_methods == [] do
    authentication_methods
    |> Enum.map(fn authentication_method ->
      Enum.into(authentication_method, %{}, fn {k, v} -> {String.to_atom(k), v} end)
    end)
  end

  def render("person_authentication_methods.json", %{
        id: person_id,
        person_authentication_methods: authentication_methods
      }) do
    authentication_methods
    |> Enum.map(fn authentication_method ->
      authentication_method
      |> Map.take(extended_field(~w(type phone_number)a))
      |> Map.put(:person_id, person_id)
    end)
    |> Enum.sort(&(Date.compare(&1.updated_at, &2.updated_at) in [:gt, :eq]))
  end

  def render("person_authentication_methods.json", _), do: []

  def render("person_authentication_method.json", %PersonAuthenticationMethod{} = authentication_method) do
    authentication_method
    |> Map.take(~w(type phone_number)a)
    |> Enum.filter(fn {_, v} -> !is_nil(v) end)
    |> Enum.into(%{}, fn {k, v} -> {to_string(k), v} end)
  end

  def render("person_authentication_method.json", %{"type" => _} = authentication_method) do
    authentication_method
  end

  def render("person_authentication_method.json", _) do
    nil
  end

  defp extended_field(fields) do
    ~w(id inserted_at updated_at)a ++ fields
  end
end
