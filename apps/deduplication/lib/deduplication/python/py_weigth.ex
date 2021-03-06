defmodule Deduplication.PyWeight do
  @moduledoc """
  defines a weight of merge candidate according to merge coefficients
  """

  @behaviour Deduplication.Behaviours.PyWeightBehaviour

  @timeout 5000

  @impl true
  def weight(bin_map) when is_map(bin_map) do
    :poolboy.transaction(
      :python_workers,
      fn pid -> GenServer.call(pid, {:weight, bin_map}) end,
      @timeout
    )
  end
end
