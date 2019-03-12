defmodule PersonDeactivator.Behaviours.RPCWorkerBehaviour do
  @moduledoc false
  @callback run(service :: binary, module :: module, function :: atom, args :: list) :: term()
end
