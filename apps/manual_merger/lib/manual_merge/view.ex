defmodule ManualMerger.View do
  @moduledoc """
  Generic view for Ecto schemas.
  Iteratively converts schema to map for RPC
  """

  alias Ecto.Association.NotLoaded

  def render(entity) when is_list(entity), do: Enum.map(entity, &render/1)

  def render(%{__struct__: _} = entity) do
    Enum.reduce(~w(fields associations embeds)a, %{}, &render_schema(&1, &2, entity))
  end

  defp render_schema(_type, rendered, %{__struct__: NotLoaded}), do: rendered

  defp render_schema(:fields, rendered, entity) do
    Map.merge(rendered, get_entity_values(entity, :fields))
  end

  defp render_schema(type, rendered, entity) when type in ~w(associations embeds)a do
    Enum.reduce(get_entity_values(entity, type), rendered, fn {key, related_entity}, acc ->
      Map.put(acc, key, render(related_entity))
    end)
  end

  defp get_entity_values(%{__struct__: struct} = entity, type) do
    Map.take(entity, struct.__schema__(type))
  end
end
