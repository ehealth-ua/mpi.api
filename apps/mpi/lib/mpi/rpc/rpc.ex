defmodule MPI.Rpc do
  @moduledoc """
  This module contains functions that are called from other pods via RPC.
  """

  alias Core.Person
  alias Core.Persons.PersonsAPI
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
          merged_persons: list(map),
          master_person: %{},
          confidant_person: map,
          is_active: boolean,
          updated_by: binary,
          authentication_methods: list(map),
          gender: binary,
          birth_settlement: binary
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
  Searches person by given parameters and options

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

  Available options:
    - read_only :: true | false. Default `nil` equal to false. If true, read records from read db only (replica)
    - paginate :: true | false. Default `nil` equal to false. If true, do Repo.paginate, else do Repo.all with limit, offset

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
            master_person: nil,
            merged_persons: [],
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

      iex> MPI.Rpc.search_persons(%{"ids" => ["26e673e1-1d68-413e-b96c-407b45d9f572"]}, [:id, :first_name, :last_name], read_only: true, paginate: true)
      {:ok, [
          %{
            id: "26e673e1-1d68-413e-b96c-407b45d9f572",
            first_name: "Петро",
            last_name: "Іванов"
          }
        ]
      }
  """

  @spec search_persons(params :: map(), fields :: list() | nil, options :: list) ::
          {:error, any()} | {:ok, list(person)}
  def search_persons(%{} = params, fields \\ nil, options \\ []) do
    with :ok <- params |> Map.drop(~w(page_size page_number)) |> validate_params(),
         :ok <- validate_fields(fields),
         persons when is_map(persons) or is_list(persons) <- PersonsAPI.list(params, fields, options),
         data <- render_persons(persons, fields) do
      {:ok, data}
    else
      {:query_error, reason} -> {:error, reason}
      error -> error
    end
  end

  defp validate_params(params) do
    if Enum.empty?(params) or not Enum.all?(params, fn {k, _} -> is_binary(k) end),
      do: {:error, "search params are not specified"},
      else: :ok
  end

  defp validate_fields(nil), do: :ok

  defp validate_fields(fields) do
    allowed_fields = [:id | Person.fields()] ++ Person.preload_fields()

    if Enum.empty?(MapSet.difference(MapSet.new(fields), MapSet.new(allowed_fields))),
      do: :ok,
      else: {:error, "listed fields could not be fetched"}
  end

  defp render_persons(%Page{entries: entries} = paging, fields) do
    persons = Enum.map(entries, &render_person(&1, fields))
    paging = Map.take(paging, ~w(page_number page_size total_entries total_pages)a)
    %{data: persons, paging: paging}
  end

  defp render_persons(persons, fields) do
    Enum.map(persons, &render_person(&1, fields))
  end

  defp render_person(person, nil), do: PersonView.render("show.json", %{person: person})
  defp render_person(person, fields), do: PersonView.render("person_short.json", %{person: person, fields: fields})

  @doc """
  List person by filtering params (GQL only)

  ## Examples

      iex> MPI.Rpc.ql_search([{:last_name, :equal, "Іванов"}], [asc: :inserted_at], {100, 50})
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
            merged_persons: [],
            master_person: nil,
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

  def ql_search(filter, order_by \\ [], cursor \\ nil) when is_list(filter) and filter != [] do
    with persons when is_list(persons) <- PersonsAPI.ql_search(filter, order_by, cursor) do
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
          merged_persons: [],
          master_person: nil,
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
    case PersonsAPI.get_person_auth_method(id) do
      nil -> nil
      auth_method -> {:ok, PersonView.render("person_authentication_method.json", auth_method)}
    end
  end

  @doc """
  Creates or updates person

  Available parameters

  | Parameter                       | Type        | Example                                                  | Description                                            |
  | :-----------------------------: | :---------: | :------------------------------------------------------: | :----------------------------------------------------: |
  | id                              | `binary`    | "dfa49f43-a4e6-4963-87ee-7e3aca1f3731"                   | Primary key identifier from the database               |
  | version                         | `binary`    | "default"                                                | Record version                                         |
  | first_name                      | `binary`    | "Петро"                                                  | Patient first name                                     |
  | last_name                       | `binary`    | "Іванов"                                                 | Patient last name                                      |
  | second_name                     | `binary`    | "Миколайович"                                            | Patient second name                                    |
  | birth_date                      | `Date.t`    | ~D[2000-08-19]                                           | Patient birth date                                     |
  | birth_country                   | `binary`    | "Україна"                                                | Patient birth country                                  |
  | birth_settlement                | `binary`    | "Вінниця"                                                | Patient birth settlement                               |
  | gender                          | `binary`    | "MALE"                                                   | Patient gender                                         |
  | email                           | `binary`    | "qq2234562qq@gmail.com"                                  | Patient's email                                        |
  | tax_id                          | `binary`    | "3378115538"                                             | National person identifier                             |
  | unzr                            | `binary`    | "19900101-0001"                                          | The unique number in Unified State Register            |
  | death_date                      | `Date.t`    | ~D[2000-08-19]                                           | Patient death date                                     |
  | preferred_way_communication     | `binary`    | "email"                                                  | The way how a patient wants to be reached              |
  | invalid_tax_id                  | `boolean`   | false                                                    | Flag to show if person has invalid tax_id              |
  | is_active                       | `boolean`   | true                                                     | Flag to show whether person is active in system        |
  | secret                          | `binary`    | "secret"                                                 | Person secret word                                     |
  | emergency_contact               | `map`       | %{"first_name" => "Петро", "last_name" => "Іванов", ...} | Patient's contract person in case of emergency         |
  | confidant_person                | `map`       | %{"birth_country" => "Україна", ...}                     | The person(s) who is(are) responsible for the patient  |
  | patient_signed                  | `boolean`   | true                                                     | Flag to show that patient has signed declaration       |
  | process_disclosure_data_consent | `boolean`   | true                                                     | Flag to show that person allowed to read personal data |
  | status                          | `binary`    | active                                                   | Patient status in the system                           |
  | authentication_methods          | `list(map)` | [%{"phone_number" => "+380955947998", "type" => "OTP"}]  | The method to verify changes of patient by patient     |
  | no_tax_id                       | `boolean`   | false                                                    | Flag to show whether person rejected to have taxId     |
  | addresses                       | `list(map)` | [%{"apartment" => "23", "area" => "ЛЬВІВСЬКА", ... }]    | Patient addresses                                      |
  | phones                          | `list(map)` | [%{"number" => "+380955947998", "type" => "MOBILE"}]     | Patient phones                                         |
  | documents                       | `list(map)` | [%{"number" => "120518", "type" => "PASSPORT"}]          | Patient identification documents                       |

  ## Examples

    iex> MPI.Rpc.create_or_update_person(%{"id" => "6e8d4595-e83c-4f97-be76-c6e2b96b05f1", "birth_date" => "1990-01-01"}, "26e673e1-1d68-413e-b96c-407b45d9f572")
    {
      :ok,
      %{
        id: "6e8d4595-e83c-4f97-be76-c6e2b96b05f1",
        authentication_methods: [
          %{"type" => "NA"}
        ],
        ...
      }
    }
  """
  @spec create_or_update_person(map, binary) :: {:ok, person} | Ecto.Changeset.t() | nil | {:error, any}
  def create_or_update_person(params, consumer_id) do
    with {_, {:ok, %Person{} = person}} <- PersonsAPI.create(params, consumer_id) do
      {:ok, PersonView.render("show.json", %{person: person})}
    end
  end
end
