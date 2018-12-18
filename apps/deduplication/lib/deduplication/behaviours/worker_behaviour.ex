defmodule Deduplication.Behaviours.WorkerBehaviour do
  @moduledoc false

  @callback stop_application() :: no_return()
  @callback run_deduplication() :: atom()
end
