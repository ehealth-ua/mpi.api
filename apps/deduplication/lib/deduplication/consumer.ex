defmodule Deduplication.Consumer do
  @moduledoc """
  consume unverified persons
  """
  use Confex, otp_app: :deduplication
  use GenStage
  alias Deduplication.Match

  def start_link(%{id: id}) do
    GenStage.start_link(__MODULE__, %{}, name: id, id: id)
  end

  @impl true
  def init(%{} = state) do
    {:consumer, state}
  end

  @impl true
  def handle_cast(:stop, state) do
    {:stop, :normal, state}
  end

  @impl true
  def handle_events(persons, _from, state) do
    Match.deduplicate_persons(persons)
    {:noreply, [], state}
  end

  @impl true
  def terminate(_reason, _state), do: :ok
end
