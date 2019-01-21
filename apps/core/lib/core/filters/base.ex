defmodule Core.Filters.Base do
  @moduledoc false

  use EctoFilter
  use EctoFilter.Operators.JSON

  def apply(query, operation, type, context), do: super(query, operation, type, context)
end
