defmodule Mpi.PersonHistTest do
  use Mpi.ModelCase, async: true

  alias Mpi.PersonHist

  describe "Valid record" do
    test "successfully inserted in DB" do
      struct = %PersonHist{}
      params = %{
        first_name: "Georgios",
        last_name: "Panayiotou",
        second_name: "Kyriacos",
        birth_date: "1963-05-25",
        gender: "male",
        email: "george@michael.com",
        tax_id: "123",
        national_id: "123",
        death_date: "2016-12-25",
        is_active: false,
        documents: [],
        addresses: [],
        phones: [],
        history: [],
        inserted_by: "Eugene",
        updated_by: "Eugene"
      }

      changeset = PersonHist.changeset(struct, params)

      assert {:ok, _record} = Repo.insert(changeset)
    end
  end
end
