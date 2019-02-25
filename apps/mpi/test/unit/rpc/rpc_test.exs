defmodule MPI.RpcTest do
  @moduledoc false

  use Core.ModelCase, async: true

  import Core.Factory
  import Mox

  alias Core.DeduplicationRepo
  alias Core.Person
  alias Core.ManualMergeRequest
  alias Core.ManualMergeCandidate
  alias MPI.Rpc
  alias Scrivener.Page
  alias Ecto.Changeset
  alias Ecto.UUID

  @status_new ManualMergeRequest.status(:new)
  @status_merge ManualMergeRequest.status(:merge)
  @status_split ManualMergeRequest.status(:split)
  @status_postpone ManualMergeRequest.status(:postpone)

  setup :verify_on_exit!

  describe "search_persons/1" do
    test "search person by documents list and status" do
      %{id: person1_id} =
        insert(
          :mpi,
          :person,
          documents: [
            build(:document, type: "BIRTH_CERTIFICATE", number: "АА111"),
            build(:document, type: "PASSPORT", number: "аа222")
          ]
        )

      %{id: person2_id} =
        insert(
          :mpi,
          :person,
          documents: [
            build(:document, type: "BIRTH_CERTIFICATE", number: "АА333"),
            build(:document, type: "PASSPORT", number: "аа444")
          ]
        )

      %{id: person3_id} =
        insert(
          :mpi,
          :person,
          documents: [
            build(:document, type: "PASSPORT", number: "аа555")
          ]
        )

      insert(
        :mpi,
        :person,
        status: Person.status(:inactive),
        documents: [
          build(:document, type: "PASSPORT", number: "АА444")
        ]
      )

      insert(:mpi, :person)

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "аа444"
          },
          %{
            "type" => "PASSPORT",
            "number" => "аа555"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 2 == length(person_ids)

      assert Enum.sort([person2_id, person3_id]) == Enum.sort(person_ids)

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "АА222"
          },
          %{
            "type" => "BIRTH_CERTIFICATE",
            "number" => "АА333"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 2 == length(person_ids)

      assert Enum.sort([person1_id, person2_id]) == Enum.sort(person_ids)

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "АА222"
          },
          %{
            "type" => "BIRTH_CERTIFICATE",
            "number" => "аа111"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 1 == length(person_ids)

      assert [person1_id] == person_ids

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "аа222"
          },
          %{
            "type" => "PASSPORT",
            "number" => "АА222"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 1 == length(person_ids)

      assert [person1_id] == person_ids

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "аа222"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 1 == length(person_ids)

      assert [person1_id] == person_ids

      search_params = %{
        "documents" => [
          %{
            "type" => "BIRTH_CERTIFICATE",
            "digits" => "333"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 1 == length(person_ids)

      assert [person2_id] == person_ids

      search_params = %{
        "documents" => [
          %{
            "type" => "PASSPORT",
            "number" => "АА777"
          }
        ],
        "status" => Person.status(:active)
      }

      %Page{entries: persons} = Rpc.search_persons(search_params)
      person_ids = Enum.map(persons, fn person -> person.id end)

      assert 0 == length(person_ids)
    end
  end

  describe "search_persons/3" do
    test "success" do
      tax_id = "0123456789"
      birth_date = ~D[1990-10-10]
      phone_number = "+3809900011122"
      document_number = "АА444009"

      insert_list(10, :mpi, :person)

      insert_list(
        2,
        :mpi,
        :person,
        no_tax_id: true,
        documents: [build(:document, type: "PASSPORT", number: document_number)],
        birth_date: birth_date,
        tax_id: tax_id,
        authentication_methods: build_list(1, :authentication_method, phone_number: phone_number)
      )

      person =
        insert(
          :mpi,
          :person,
          no_tax_id: false,
          documents: [build(:document, type: "PASSPORT", number: document_number)],
          birth_date: birth_date,
          tax_id: tax_id,
          authentication_methods: build_list(1, :authentication_method, phone_number: phone_number)
        )

      filter = [
        {:authentication_methods, :contains, [%{"phone_number" => phone_number}]},
        {:tax_id, :equal, tax_id},
        {:birth_date, :equal, birth_date},
        {:documents, nil, [{:number, :equal, document_number}, {:type, :equal, "PASSPORT"}]}
      ]

      {:ok, persons} = Rpc.search_persons(filter, [asc: :no_tax_id], {0, 10})

      assert 3 == length(persons)
      assert person.id == hd(persons).id
    end

    test "success by persons id" do
      insert_list(4, :mpi, :person)

      persons = insert_list(2, :mpi, :person)
      persons_ids = Enum.map(persons, & &1.id)
      filter = [{:id, :in, persons_ids}]
      {:ok, persons} = Rpc.search_persons(filter)

      assert 2 == length(persons)
    end
  end

  describe "search_persons/2 with fields" do
    test "search_persons/2 by ids" do
      fields = ~w(id first_name last_name second_name birth_date)a
      %{id: id1} = insert(:mpi, :person)
      %{id: id2} = insert(:mpi, :person)
      insert(:mpi, :person)

      Rpc.search_persons(%{"ids" => Enum.join([id1, id2], ",")}, fields)
    end

    test "search_persons/2 with fields by ids not found" do
      fields = ~w(id first_name last_name second_name birth_date)a
      insert(:mpi, :person)

      {:ok, []} = Rpc.search_persons(%{"ids" => Enum.join([UUID.generate()], ",")}, fields)
    end

    test "search_persons/2 with empty search params" do
      fields = ~w(id first_name last_name second_name birth_date)a
      insert(:mpi, :person)

      {:error, "search params is not specified"} = Rpc.search_persons(%{}, fields)
    end

    test "search_persons/2  with not-existing field return error" do
      %{id: id} = insert(:mpi, :person)

      assert {:error, "invalid search characters"} ==
               Rpc.search_persons(%{"id" => id}, [:id, :not_existing_field])
    end
  end

  describe "get_person_by_id/1" do
    test "success" do
      %{id: id} = insert(:mpi, :person)

      assert {:ok, %{id: ^id}} = Rpc.get_person_by_id(id)
    end

    test "not found" do
      refute Rpc.get_person_by_id(UUID.generate())
    end
  end

  describe "reset_auth_method/2" do
    test "success" do
      %{id: id} = insert(:mpi, :person, authentication_methods: [%{"type" => "PHONE"}])

      person = Rpc.reset_auth_method(id, UUID.generate())

      assert {:ok, %{id: ^id, authentication_methods: [%{"type" => "NA"}]}} = person
    end

    test "person inactive" do
      %{id: id} =
        insert(:mpi, :person, status: Person.status(:inactive), authentication_methods: [%{"type" => "PHONE"}])

      assert {:error, {:conflict, "Invalid status MPI for this action"}} = Rpc.reset_auth_method(id, UUID.generate())
    end

    test "not found" do
      refute Rpc.reset_auth_method(UUID.generate(), UUID.generate())
    end
  end

  describe "get_auth_method/1" do
    test "success" do
      %{id: id1} =
        insert(:mpi, :person,
          authentication_methods: [
            %{
              type: "OTP",
              phone_number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}"
            }
          ]
        )

      %{id: id2} =
        insert(:mpi, :person,
          authentication_methods: [
            %{
              type: "OFFLINE"
            }
          ]
        )

      assert {:ok, %{"phone_number" => _, "type" => "OTP"}} = Rpc.get_auth_method(id1)
      assert {:ok, %{"type" => "OFFLINE"}} = Rpc.get_auth_method(id2)
    end

    test "person not found" do
      refute Rpc.get_auth_method(UUID.generate())
    end
  end

  describe "search_manual_merge_requests/3" do
    setup do
      person = insert(:mpi, :person)
      master_person = insert(:mpi, :person)
      merge_candidate = insert(:mpi, :merge_candidate, person: person, master_person: master_person)

      %{merge_candidate: merge_candidate}
    end

    test "success with filter params", %{
      merge_candidate: %{id: merge_candidate_id, person: person, master_person: master_person}
    } do
      manual_merge_candidate = insert(:deduplication, :manual_merge_candidate, merge_candidate_id: merge_candidate_id)

      insert_list(2, :deduplication, :manual_merge_request,
        manual_merge_candidate: manual_merge_candidate,
        status: @status_merge
      )

      insert_list(4, :deduplication, :manual_merge_request,
        manual_merge_candidate: manual_merge_candidate,
        status: @status_new
      )

      insert_list(8, :deduplication, :manual_merge_request)

      assert {:ok, [resp_entity | _] = resp_entities} =
               Rpc.search_manual_merge_requests([{:status, :equal, @status_merge}], [desc: :inserted_at], {0, 10})

      assert 2 == length(resp_entities)

      assert master_person.id == get_in(resp_entity, [:manual_merge_candidate, :merge_candidate, :master_person, :id])
      assert person.id == get_in(resp_entity, [:manual_merge_candidate, :merge_candidate, :person, :id])
    end

    test "success on empty response" do
      assert {:ok, []} == Rpc.search_manual_merge_requests([{:status, :equal, @status_new}], [], {0, 10})
    end
  end

  describe "assign_manual_merge_candidate/1" do
    setup do
      person = insert(:mpi, :person)
      master_person = insert(:mpi, :person)
      merge_candidate = insert(:mpi, :merge_candidate, person: person, master_person: master_person)

      %{merge_candidate: merge_candidate}
    end

    test "success", %{merge_candidate: merge_candidate} do
      manual_merge_candidate = insert(:deduplication, :manual_merge_candidate, merge_candidate_id: merge_candidate.id)

      manual_merge_candidate_id = manual_merge_candidate.id
      actor_id = UUID.generate()

      assert {:ok,
              %{
                assignee_id: ^actor_id,
                manual_merge_candidate: %{
                  id: ^manual_merge_candidate_id,
                  assignee_id: ^actor_id
                }
              }} = Rpc.assign_manual_merge_candidate(actor_id)
    end
  end

  describe "process_manual_merge_request/4" do
    setup do
      person = insert(:mpi, :person)
      master_person = insert(:mpi, :person)
      merge_candidate = insert(:mpi, :merge_candidate, person: person, master_person: master_person)

      manual_merge_candidate =
        insert(:deduplication, :manual_merge_candidate,
          person_id: merge_candidate.person_id,
          master_person_id: merge_candidate.master_person_id,
          merge_candidate_id: merge_candidate.id
        )

      %{merge_candidate: merge_candidate, manual_merge_candidate: manual_merge_candidate}
    end

    test "successful merge request", context do
      %{merge_candidate: merge_candidate, manual_merge_candidate: manual_merge_candidate} = context

      expect(CandidatesMergerKafkaMock, :publish_person_deactivation_event, fn candidates, _system_user_id ->
        assert [%{id: merge_candidate.id, person_id: merge_candidate.person_id}] == candidates
        :ok
      end)

      merge_request = insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_merge_candidate)

      insert_list(2, :deduplication, :manual_merge_request,
        status: @status_merge,
        manual_merge_candidate: manual_merge_candidate
      )

      assert {:ok, %{status: @status_merge}} =
               Rpc.process_manual_merge_request(merge_request.id, @status_merge, merge_request.assignee_id)

      manual_merge_candidate = DeduplicationRepo.get(ManualMergeCandidate, manual_merge_candidate.id)
      assert ManualMergeCandidate.status(:processed) == manual_merge_candidate.status
    end

    test "successful split request", %{manual_merge_candidate: manual_merge_candidate} do
      merge_request = insert(:deduplication, :manual_merge_request, manual_merge_candidate: manual_merge_candidate)

      assert {:ok, %{status: @status_split}} =
               Rpc.process_manual_merge_request(merge_request.id, @status_split, merge_request.assignee_id)
    end

    test "invalid comment type" do
      %{id: id, assignee_id: assignee_id} = insert(:deduplication, :manual_merge_request)

      assert {:error, %Changeset{valid?: false}} =
               Rpc.process_manual_merge_request(id, @status_merge, assignee_id, %{invalid: :type})
    end
  end

  describe "can_assign_new_manual_merge_request/1" do
    setup %{max_postponed_requests: max_postponed_requests} do
      prev_config = Application.get_env(:core, Core.ManualMerge)

      Application.put_env(
        :core,
        Core.ManualMerge,
        Keyword.replace!(prev_config, :max_postponed_requests, max_postponed_requests)
      )

      on_exit(fn -> Application.put_env(:core, Core.ManualMerge, prev_config) end)

      :ok
    end

    @tag max_postponed_requests: 1
    test "suceess with no merge_requests" do
      assignee_id = UUID.generate()

      assert {:ok, true} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end

    @tag max_postponed_requests: 3
    test "suceess with few merge_requests, filter by assignee_id" do
      assignee_id = UUID.generate()
      insert_list(2, :deduplication, :manual_merge_request, assignee_id: assignee_id, status: @status_postpone)
      insert_list(4, :deduplication, :manual_merge_request, status: @status_postpone)

      assert {:ok, true} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end

    @tag max_postponed_requests: 0
    test "fail with zero limit" do
      assignee_id = UUID.generate()

      assert {:ok, false} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end

    @tag max_postponed_requests: 5
    test "fail when already has new merge_request" do
      assignee_id = UUID.generate()
      insert(:deduplication, :manual_merge_request, assignee_id: assignee_id, status: @status_new)

      assert {:ok, false} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end

    @tag max_postponed_requests: 5
    test "fail to assign new merge_request due to limit" do
      assignee_id = UUID.generate()
      insert_list(5, :deduplication, :manual_merge_request, assignee_id: assignee_id, status: @status_postpone)

      assert {:ok, false} == Rpc.can_assign_new_manual_merge_request(assignee_id)
    end
  end
end
