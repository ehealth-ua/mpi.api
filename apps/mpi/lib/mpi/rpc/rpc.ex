defmodule MPI.Rpc do
  @moduledoc """
  This module contains functions that are called from other pods via RPC.
  """

  alias Core.ManualMerge
  alias Core.Person
  alias Core.Persons.PersonsAPI
  alias MPI.Web.ManualMergeRequestView
  alias MPI.Web.PersonView
  alias Scrivener.Page

  @type person() :: %{
          process_disclosure_data_consent: boolean(),
          death_date: Date,
          documents: list(map),
          tax_id: binary,
          second_name: binary,
          secret: binary,
          birth_country: binary,
          email: binary,
          first_name: binary,
          no_tax_id: boolean,
          invalid_tax_id: boolean,
          preferred_way_communication: binary,
          inserted_by: binary,
          last_name: binary,
          phones: list(map),
          id: binary,
          inserted_at: DateTime,
          birth_date: Date,
          version: binary,
          patient_signed: boolean,
          unzr: binary,
          emergency_contact: map,
          updated_at: DateTime,
          status: binary,
          addresses: list(map),
          merged_ids: list(binary),
          confidant_person: map,
          is_active: boolean,
          updated_by: binary,
          authentication_methods: map,
          gender: binary,
          birth_settlement: binary
        }

  @type manual_merge_request() :: %{
          id: binary,
          status: binary,
          comment: binary,
          assignee_id: binary,
          manual_merge_candidate: manual_merge_candidate(),
          inserted_at: DateTime,
          updated_at: DateTime
        }

  @type manual_merge_candidate() :: %{
          id: binary,
          status: binary,
          decision: binary,
          assignee_id: binary,
          person_id: binary,
          master_person_id: binary,
          inserted_at: DateTime,
          updated_at: DateTime,
          merge_candidate: merge_candidate()
        }

  @type merge_candidate() :: %{
          status: binary,
          config: map,
          details: map,
          score: float,
          person: person(),
          master_person: person(),
          inserted_at: DateTime,
          updated_at: DateTime
        }

  @type successfull_search_response() :: %Page{
          entries: list(person),
          page_number: number(),
          page_size: number(),
          total_entries: number(),
          total_pages: number()
        }

  @doc """
  Searches person by given parameters

  Available parameters:

  | Parameter          | Type             | Example                                              | Description                                        |
  | :----------------: | :--------------: | :--------------------------------------------------: | :------------------------------------------------: |
  | first_name         | `binary`         | Петро                                                |                                                    |
  | last_name          | `binary`         | Іванов                                               |                                                    |
  | second_name        | `binary`         | Миколайович                                          |                                                    |
  | birth_date         | `DateTime`       | 1991-08-19T00:00:00.000Z                             |                                                    |
  | tax_id             | `binary`         | 3126509816                                           |                                                    |
  | unzr               | `binary`         | 19900101-0001                                        | The record number in the demographic register      |
  | phone_number       | `binary`         | +380508887700                                        | Any phone number that is present in phones         |
  | auth_phone_number  | `binary`         | +380508887700                                        | Phone number that is used for authentication       |
  | ids                | `list(binary)`   | ['56615208-b41f-4f32-9221-d22eb2db7dfb', ...]        | List of id's                                       |
  | documents          | `list(map)`      | [%{"type" => "PASSPORT", "number" => "123456"}, ...] | List of documents to search by with `or` condition |

  Returns `%Scrivener.Page{entries: list(person), page_number: number(), page_size: number(), total_entries: number(), total_pages: number()}`.

  ## Examples

      iex> MPI.Rpc.search_persons(%{"last_name" => "Іванов"})
      %Scrivener.Page{
        entries: [
          %{
            id: "26e673e1-1d68-413e-b96c-407b45d9f572",
            first_name: "Петро",
            last_name: "Іванов",
            second_name: "Миколайович",
            birth_country: "Ukraine",
            inserted_at: #DateTime<2018-11-05 09:54:49.406483Z>,
            updated_at: #DateTime<2018-11-05 09:54:49.406486Z>,
            inserted_by: "bc11085d-3e47-49a5-90c4-c787ee41c1ba",
            updated_by: "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9",
            invalid_tax_id: false,
            email: "petroivanov@email.com",
            unzr: "19900101-0001",
            process_disclosure_data_consent: true,
            addresses: [],
            death_date: nil,
            birth_settlement: "Київ",
            preferred_way_communication: nil,
            merged_ids: [],
            documents: [],
            gender: "MALE",
            patient_signed: true,
            no_tax_id: false,
            secret: "sEcReT",
            birth_date: ~D[1991-08-27],
            is_active: true,
            version: "1",
            emergency_contact: %{},
            tax_id: "3126509816",
            confidant_person: nil,
            authentication_methods: [
              %{"phone_number" => "+380508887700", "type" => "OTP"}
            ],
            phones: [],
            status: "active"
          }
        ],
        page_number: 1,
        page_size: 1,
        total_entries: 1,
        total_pages: 1
      }

      iex> MPI.Rpc.search_persons([:id, :first_name, :last_name], %{"ids" => ["26e673e1-1d68-413e-b96c-407b45d9f572"]})
      {:ok, [
          %{
            id: "26e673e1-1d68-413e-b96c-407b45d9f572",
            first_name: "Петро",
            last_name: "Іванов"
          }
        ]
      }
  """

  @spec search_persons(params :: map()) :: {:error, any()} | successfull_search_response
  def search_persons(%{} = params), do: search_persons(params, nil)

  @spec search_persons(params :: map(), fields :: list()) :: {:error, any()} | successfull_search_response
  def search_persons(%{} = params, fields) do
    with {:search_params, true} <- {:search_params, !Enum.empty?(params)},
         %Page{entries: persons} = page <- PersonsAPI.search(params, fields) do
      if is_nil(fields),
        do: %Page{page | entries: PersonView.render("index.json", %{persons: persons})},
        else: {:ok, Enum.map(persons, &PersonView.render("person_short.json", %{person: &1, fields: fields}))}
    else
      {:search_params, false} -> {:error, "search params is not specified"}
      {:query_error, reason} -> {:error, reason}
      err -> err
    end
  end

  @doc """
  Searches person by filtering params

  ## Examples

      iex> MPI.Rpc.search_persons([{:last_name, :equal, "Іванов"}], [asc: :inserted_at], {100, 50})
      {:ok, [
          %{
            id: "26e673e1-1d68-413e-b96c-407b45d9f572",
            first_name: "Петро",
            last_name: "Іванов",
            second_name: "Миколайович",
            birth_country: "Ukraine",
            inserted_at: #DateTime<2018-11-05 09:54:49.406483Z>,
            updated_at: #DateTime<2018-11-05 09:54:49.406486Z>,
            inserted_by: "bc11085d-3e47-49a5-90c4-c787ee41c1ba",
            updated_by: "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9",
            invalid_tax_id: false,
            email: "petroivanov@email.com",
            unzr: "19900101-0001",
            process_disclosure_data_consent: true,
            addresses: [],
            death_date: nil,
            birth_settlement: "Київ",
            preferred_way_communication: nil,
            merged_ids: [],
            documents: [],
            gender: "MALE",
            patient_signed: true,
            no_tax_id: false,
            secret: "sEcReT",
            birth_date: ~D[1991-08-27],
            is_active: true,
            version: "1",
            emergency_contact: %{},
            tax_id: "3126509816",
            confidant_person: nil,
            authentication_methods: [
              %{"phone_number" => "+380508887700", "type" => "OTP"}
            ],
            phones: [],
            status: "active"
          }
        ]
      }
  """

  def search_persons(filter, order_by \\ [], cursor \\ nil) when is_list(filter) and filter != [] do
    with persons when is_list(persons) <- PersonsAPI.search(filter, order_by, cursor) do
      {:ok, PersonView.render("index.json", %{persons: persons})}
    else
      {:query_error, reason} -> {:error, reason}
      err -> err
    end
  end

  @doc """
  Resolves person by id

  ## Examples

      iex> MPI.Rpc.get_person_by_id("26e673e1-1d68-413e-b96c-407b45d9f572")
      {
        :ok,
        %{
          id: "26e673e1-1d68-413e-b96c-407b45d9f572",
          first_name: "Петро",
          last_name: "Іванов",
          second_name: "Миколайович",
          birth_country: "Ukraine",
          inserted_at: #DateTime<2018-11-05 09:54:49.406483Z>,
          updated_at: #DateTime<2018-11-05 09:54:49.406486Z>,
          inserted_by: "bc11085d-3e47-49a5-90c4-c787ee41c1ba",
          updated_by: "d221d7f1-81cb-44d3-b6d4-8d7e42f97ff9",
          invalid_tax_id: false,
          email: "petroivanov@email.com",
          unzr: "19900101-0001",
          process_disclosure_data_consent: true,
          addresses: [%{
            "APARTMENT" => "",
            "BUILDING" => "48а",
            "COUNTRY" => "UA",
            "SETTLEMENT" => "ХАРКІВ",
            "SETTLEMENT_ID" => "1241d1f9-ae81-4fe5-b614-f4f780a5acf0",
            "SETTLEMENT_TYPE" => "CITY",
            "STREET" => "Героїв Праці",
            "STREET_TYPE" => " STREET",
            "TYPE" => "REGISTRATION",
            "area" => "ХАРКІВСЬКА"
          }],
          death_date: nil,
          birth_settlement: "Київ",
          preferred_way_communication: nil,
          merged_ids: [],
          documents: [],
          gender: "MALE",
          patient_signed: true,
          no_tax_id: false,
          secret: "sEcReT",
          birth_date: ~D[1991-08-27],
          is_active: true,
          version: "1",
          emergency_contact: %{},
          tax_id: "3126509816",
          confidant_person: nil,
          authentication_methods: [
            %{"phone_number" => "+380508887700", "type" => "OTP"}
          ],
          phones: [],
          status: "active"
        }
      }
  """
  @spec get_person_by_id(id :: binary()) :: nil | {:ok, person()}
  def get_person_by_id(id) do
    with %Person{} = person <- PersonsAPI.get_by_id(id) do
      {:ok, PersonView.render("show.json", %{person: person})}
    end
  end

  @doc """
  Reset authentication method for person by `id` with `actor_id` UUID

  ## Examples

      iex> MPI.Rpc.reset_auth_method("26e673e1-1d68-413e-b96c-407b45d9f572", "22f673e1-1d68-413e-b96c-407b45d9ffa3")
      {
        :ok,
        %{
          id: "26e673e1-1d68-413e-b96c-407b45d9f572",
          authentication_methods: [
            %{"type" => "NA"}
          ],
          ...
        }
      }
  """
  @spec reset_auth_method(id :: binary(), actor_id :: binary()) :: {:error, term()} | {:ok, person()}
  def reset_auth_method(id, actor_id) do
    with {:ok, person} <- PersonsAPI.reset_auth_method(id, %{"authentication_methods" => [%{"type" => "NA"}]}, actor_id) do
      {:ok, PersonView.render("show.json", %{person: person})}
    end
  end

  @doc """
  Get authentication method for person by `id`

  ## Examples

      iex> MPI.Rpc.get_auth_method("26e673e1-1d68-413e-b96c-407b45d9f572")
      {:ok, %{"type" => "OTP", "phone_number" => "+380630000000"}}
  """
  @spec get_auth_method(id :: binary()) :: nil | {:ok, map()}
  def get_auth_method(id) do
    with %Person{} = person <- PersonsAPI.get_by_id(id) do
      {:ok, PersonsAPI.get_person_auth_method(person)}
    end
  end

  @doc """
  Search for Manual Merge Requests with its references: manual_merge_candidate -> merge_candidate -> [person, master_person]
  Check available formats for filter here https://github.com/edenlabllc/ecto_filter

  Available parameters:

  | Parameter           | Type                          | Example                                   | Description                     |
  | :-----------------: | :---------------------------: | :---------------------------------------: | :-----------------------------: |
  | filter              | `list`                        | `[{:status, :equal, "MERGE"}]`            | Required. Uses filtering format |
  | order_by            | `list`                        | `[asc: :inserted_at]` or `[desc: :status]`|                                 |
  | cursor              | `{integer, integer}` or `nil` | `{0, 10}`                                 |                                 |

  ## Examples
      iex> MPI.Rpc.search_manual_merge_requests([{:status, :equal, "NEW"}], [desc: :status], {0, 10})
      {:ok, [%{
        id: "6868d53f-6e37-46bc-af34-29e650446310",
        assignee_id: "dbf7ba19-1186-4ac0-a410-6499abe40a7c",
        comment: nil,
        manual_merge_candidate: %{...},
        status: "MERGE",
        inserted_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        updated_at: #DateTime<2019-02-04 14:08:42.434619Z>
      }]}
  """
  @spec search_manual_merge_requests(list, list, {offset :: integer, limit :: integer} | nil) ::
          {:ok, list(manual_merge_request)}
  def search_manual_merge_requests([_ | _] = filter, order_by \\ [], cursor \\ nil) do
    with {:ok, manual_merge_requests} <- ManualMerge.search_manual_merge_requests(filter, order_by, cursor) do
      {:ok, ManualMergeRequestView.render("index.json", %{manual_merge_requests: manual_merge_requests})}
    end
  end

  @doc """
  Assign merge candidate to review

  Available parameters:

  | Parameter           | Type                | Example                                  | Description                     |
  | :-----------------: | :-----------------: | :--------------------------------------: | :-----------------------------: |
  | actor_id            | `binary`            | `"1e6a23b8-d7d0-42f7-a414-fd08b86c6497"` | Required. ID of the acting user |

  ## Examples

      iex> MPI.Rpc.assign_merge_candidate("1e6a23b8-d7d0-42f7-a414-fd08b86c6497")
      {:ok, %{
        id: "acdb554f-455d-47c8-b379-6d9c4d7e18f4",
        assignee_id: "1e6a23b8-d7d0-42f7-a414-fd08b86c6497",
        comment: nil,
        manual_merge_candidate: %{...},
        status: "NEW",
        inserted_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        updated_at: #DateTime<2019-02-04 14:08:42.434619Z>
      }}
  """
  @spec assign_manual_merge_candidate(actor_id :: binary()) :: {:ok, manual_merge_request()} | {:error, term()}
  def assign_manual_merge_candidate(actor_id) do
    with {:ok, merge_request} <- ManualMerge.assign_merge_candidate(actor_id) do
      {:ok, ManualMergeRequestView.render("show.json", %{manual_merge_request: merge_request})}
    end
  end

  @doc """
  Process Manual Merge Request, updates it status and if it necessary -
  process Manual Merge Candidate and deactivate Person

  ## Examples

      iex> MPI.Rpc.process_manual_merge_request("26e673e1-1d68-413e-b96c-407b45d9f572", "MERGE", "5768d53f-6e37-46bc-af34-29e650446321")
       {:ok, %{
        id: "26e673e1-1d68-413e-b96c-407b45d9f572",
        assignee_id: "5768d53f-6e37-46bc-af34-29e650446321",
        comment: nil,
        manual_merge_candidate: %{...},
        status: "MERGE",
        inserted_at: #DateTime<2019-02-04 14:08:42.434612Z>,
        updated_at: #DateTime<2019-02-04 14:08:42.434619Z>
      }}
  """
  @spec process_manual_merge_request(
          id :: binary(),
          status :: binary(),
          actor_id :: binary(),
          comment :: binary() | nil
        ) :: {:ok, manual_merge_request()} | {:error, term()}
  def process_manual_merge_request(id, status, actor_id, comment \\ nil) do
    with {:ok, manual_merge_request} <- ManualMerge.process_merge_request(id, status, actor_id, comment) do
      {:ok, ManualMergeRequestView.render("show.json", %{manual_merge_request: manual_merge_request})}
    end
  end

  @doc """
  Checks if could assign new ManualMergeRequest

  ## Examples
      iex> MPI.Rpc.can_assign_new_manual_merge_request("05127087-5f95-4348-83aa-ea5d259b6601")
      {:ok, true}
  """
  @spec can_assign_new_manual_merge_request(binary) :: {:ok, boolean}
  def can_assign_new_manual_merge_request(assignee_id), do: {:ok, ManualMerge.can_assign_new?(assignee_id)}
end
