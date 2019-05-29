defmodule Core.Persons.Filter do
  @moduledoc false

  use EctoFilter
  use EctoFilter.Operators.JSON

  alias Core.Person
  alias Core.PersonDocument

  def apply(query, {:status, :equal, value}, _type, Person) do
    where(query, [..., p], fragment("upper(?)", p.status) == ^value)
  end

  def apply(query, {:number, :equal, value}, _type, PersonDocument) do
    where(query, [..., d], fragment("lower(?) = ?", d.number, ^String.downcase(value)))
  end

  def apply(query, operation, type, context) do
    super(query, operation, type, context)
  end
end
