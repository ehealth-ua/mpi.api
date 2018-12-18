defmodule Core.Rpc do
  @moduledoc """
  This module contains functions that are called from other pods via RPC.
  """

  alias Core.Person
  alias Core.Persons.PersonsAPI
  alias Core.Persons.Renderer
  alias Scrivener.Page

  @type person() :: %Person{
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

      iex> Core.Rpc.search_persons(%{"last_name" => "Іванов"})
      %Scrivener.Page{
        entries: [
          %Core.Person{
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
  """

  @spec search_persons(params :: map()) :: {:error, any()} | successfull_search_response
  def search_persons(params) do
    with %Page{entries: entries} = page <- PersonsAPI.search(params) do
      %Page{page | entries: Enum.map(entries, fn entry -> Renderer.render("person.json", entry) end)}
    end
  end
end
