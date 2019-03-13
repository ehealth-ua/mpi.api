defmodule Deduplication.PersistentTerm do
  @moduledoc false

  alias Deduplication.MixProject

  @version MixProject.project()[:version]

  def store_details do
    :persistent_term.put(:deduplication_details, %{
      start_date: DateTime.utc_now(),
      version: @version
    })
  end

  def details do
    :persistent_term.get(:deduplication_details)
  end
end
