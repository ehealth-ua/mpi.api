defmodule Deduplication.Behaviours.ProducerBehaviour do
  @moduledoc false

  @callback stop_application() :: no_return()
end
