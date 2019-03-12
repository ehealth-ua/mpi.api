defmodule PersonDeactivator.Rpc.Worker do
  @moduledoc false

  use KubeRPC.Client, :person_deactivator
end
