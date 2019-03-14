defmodule Core.TelemetryHandler.DeduplicationRepoHandler do
  @moduledoc false

  use EhealthLogger.TelemetryHandler, prefix: :core, repo: :deduplication_repo
end
