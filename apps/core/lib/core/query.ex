defmodule Core.Query do
  @moduledoc false

  import Ecto.Query, only: [offset: 2, limit: 2]

  def apply_cursor(query, {offset, limit}), do: query |> offset(^offset) |> limit(^limit)
  def apply_cursor(query, _), do: query
end
