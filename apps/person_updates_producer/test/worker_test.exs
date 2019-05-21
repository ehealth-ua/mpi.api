defmodule PersonUpdateProducer.WorkerTest do
  @moduledoc false

  use ExUnit.Case, async: true
  alias Core.PersonUpdate
  alias Core.Repo
  alias Ecto.Adapters.SQL.Sandbox
  alias Ecto.UUID
  alias PersonUpdatesProducer.Jobs.PersonUpdatesPublisher
  import Core.Factory
  import Mox

  setup :set_mox_global

  setup do
    :ok = Sandbox.checkout(Repo)
    Sandbox.mode(Repo, {:shared, self()})
  end

  describe "worker tests" do
    test "success start worker" do
      expect(KafkaMock, :publish_person_event, fn _, _, _, _, _, _ -> :ok end)
      person_id = UUID.generate()
      insert(:mpi, :person_update, person_id: person_id)
      assert [_] = Repo.all(PersonUpdate)
      PersonUpdatesPublisher.run()
      assert [] = Repo.all(PersonUpdate)
    end
  end
end
