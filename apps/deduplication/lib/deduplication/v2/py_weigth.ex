defmodule Deduplication.V2.PyWeight do
  @moduledoc """
  defines a weight of merge candidate accoring to merge koeficients
  """

  @behaviour Deduplication.Behaviours.PyWeightBehaviour

  @timeout 5000

  @impl true
  def weight(model) when is_map(model) do
    :poolboy.transaction(
      :python_workers,
      fn pid -> GenServer.call(pid, {:weight, model}) end,
      @timeout
    )
  end
end
