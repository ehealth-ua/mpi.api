defmodule Deduplication.V2.ConsumerTest do
  @moduledoc false
  use Core.ModelCase, async: false
  import Core.Factory

  alias Core.Person
  alias Core.Repo
  alias Deduplication.Kafka.GenConsumer
  alias Ecto.UUID

  @person_status_inactive Person.status(:inactive)

  describe "status inactive" do
    test "mark peron inactive" do
      person = insert(:mpi, :person)
      actor_id = UUID.generate()
      assert :ok = GenConsumer.deactivate_person(person.id, actor_id)

      assert %Person{updated_by: ^actor_id, status: @person_status_inactive} =
               Repo.get!(Person, person.id)
    end

    test "mark non existing peron inactive" do
      id = UUID.generate()
      refute GenConsumer.deactivate_person(id, id)
      refute Repo.one(Person)
    end
  end
end
