defmodule PersonDeactivator.Behaviours.WorkerBehaviour do
  @moduledoc false

  @callback stop_application() :: no_return()
  @callback run_deactivation() :: atom()
end
