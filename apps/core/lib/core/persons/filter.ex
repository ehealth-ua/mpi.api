defmodule Core.Persons.Filter do
  @moduledoc false

  use EctoFilter
  use EctoFilter.Operators.JSON

  def apply(query, {:status, :equal, value}, _type, Core.Person) do
    where(query, [..., p], fragment("upper(?)", p.status) == ^value)
  end

  def apply(query, operation, type, context), do: super(query, operation, type, context)
end
