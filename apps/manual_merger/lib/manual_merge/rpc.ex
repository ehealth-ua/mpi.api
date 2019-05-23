defmodule ManualMerger.Rpc do
  @moduledoc """
  This module contains functions that are called from other pods via RPC.
  """

  alias Core.ManualMerge
  alias ManualMerger.View

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
          merged_persons: list(map),
          master_person: %{},
          confidant_person: map,
          is_active: boolean,
          updated_by: binary,
          authentication_methods: list(map),
          gender: binary,
          birth_settlement: binary
        }

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
      {:ok, View.render(manual_merge_requests)}
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
      {:ok, View.render(merge_request)}
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
    with {:ok, manual_merge_request} <- CandidatesMerger.process_merge_request(id, status, actor_id, comment) do
      {:ok, View.render(manual_merge_request)}
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
