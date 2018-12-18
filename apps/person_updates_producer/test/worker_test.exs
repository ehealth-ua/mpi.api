defmodule PersonUpdateProducer.WorkerTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias Core.PersonUpdate
  alias Core.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID
  alias PersonUpdatesProducer.Worker
  import Core.Factory
  import Mox

  setup :set_mox_global

  setup do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})
  end

  describe "worker tests" do
    test "success start worker" do
      expect(WorkerMock, :stop_application, fn -> :ok end)
      expect(KafkaMock, :publish_person_event, fn _, _, _ -> :ok end)
      person_id = UUID.generate()
      insert(:person_update, person_id: person_id)
      assert [_] = Repo.all(PersonUpdate)
      {:ok, _pid} = GenServer.start_link(Worker, [])
      :timer.sleep(100)
      assert [] = Repo.all(PersonUpdate)
    end
  end
end
