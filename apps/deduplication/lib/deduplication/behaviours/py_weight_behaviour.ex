defmodule Deduplication.Behaviours.PyWeightBehaviour do
  @moduledoc false

  @callback weight(map()) :: float()
end
