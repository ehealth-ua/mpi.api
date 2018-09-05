defmodule Deduplication.Behaviours.ClientBehaviour do
  @moduledoc false

  @callback post!(url :: binary(), body :: any(), headers :: HTTPoison.Base.headers()) ::
              HTTPoison.Response.t() | HTTPoison.AsyncResponse.t()
end
