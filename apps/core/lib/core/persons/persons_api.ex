defmodule Core.Persons.PersonsAPI do
  @moduledoc false

  import Core.Persons.Filter, only: [filter: 2]
  import Core.Query, only: [apply_cursor: 2]
  import Ecto.Changeset
  import Ecto.Query

  alias Core.Maybe
  alias Core.Person
  alias Core.PersonAuthenticationMethod
  alias Core.Persons.Search
  alias Core.Repo
  alias Ecto.Changeset

  @read_repo Application.get_env(:core, :repos)[:read_repo]
  @person_status_active Person.status(:active)

  defp trim_spaces(input_string), do: input_string |> String.split() |> Enum.join(" ")

  defp trim_name_spaces(params) do
    params
    |> Map.take(~w(first_name second_name last_name))
    |> Enum.reduce(%{}, fn {key, value}, acc ->
      Map.put(acc, key, Maybe.map(value, &trim_spaces/1))
    end)
    |> Map.merge(params, fn _key, value1, _value2 -> value1 end)
  end

  def changeset(%Person{} = person, params) do
    changeset =
      person
      |> cast(trim_name_spaces(params), Person.fields())
      |> cast_assoc(:addresses)
      |> cast_assoc(:phones)
      |> cast_assoc(:documents, required: true)
      |> validate_required(Person.fields_required())
      |> unique_constraint(:last_name, name: :persons_uniq_index)

    with %Changeset{valid?: true} <- changeset,
         person <- apply_changes(changeset) do
      authentication_methods = person.authentication_methods

      changeset
      |> cast(%{person_authentication_methods: authentication_methods}, [])
      |> cast_assoc(:person_authentication_methods, required: true)
    else
      _ -> changeset
    end
  end

  defp get_by_unique(person) do
    with [%Person{} = person | _] <-
           person
           |> Map.take(~w(tax_id birth_date last_name first_name second_name status)a)
           |> Enum.filter(fn {_, v} -> !is_nil(v) end)
           |> Enum.into(%{}, fn {k, v} ->
             {to_string(k), v}
           end)
           |> find_persons(nil, []) do
      {:ok, person}
    else
      _ -> nil
    end
  end

  def get_by_id(id) do
    Person
    |> where([p], p.id == ^id)
    |> join(:left, [p], phones in assoc(p, :phones), as: :phones)
    |> join(:left, [p], d in assoc(p, :documents), as: :documents)
    |> join(:left, [p], a in assoc(p, :addresses), as: :addresses)
    |> join(:left, [p], mp in assoc(p, :merged_persons), as: :merged_persons)
    |> join(:left, [p], m in assoc(p, :master_person), as: :master_person)
    |> join(:left, [p], am in assoc(p, :person_authentication_methods), as: :person_authentication_methods)
    |> preload(
      [
        phones: phones,
        documents: documents,
        addresses: addresses,
        merged_persons: merged_persons,
        master_person: master_person,
        person_authentication_methods: person_authentication_methods
      ],
      phones: phones,
      documents: documents,
      addresses: addresses,
      merged_persons: merged_persons,
      master_person: master_person,
      person_authentication_methods: person_authentication_methods
    )
    |> Repo.one()
  end

  def create(%{"id" => id} = params, consumer_id) when is_binary(id) do
    params = params |> Map.put("updated_by", consumer_id) |> Map.delete("id")

    with %Person{} = person <- get_by_id(id),
         :ok <- person_is_active(person),
         %Changeset{valid?: true} = changeset <- changeset(person, params),
         {:ok, person} <- Repo.update_and_log(changeset, consumer_id) do
      {:ok, {:ok, person}}
    end
  end

  def create(params, consumer_id) do
    params = Map.merge(params, %{"inserted_by" => consumer_id, "updated_by" => consumer_id})

    with %Changeset{valid?: true} = changeset <- changeset(%Person{}, params) do
      case get_by_unique(Changeset.apply_changes(changeset)) do
        nil ->
          with {:ok, person} <- Repo.insert_and_log(changeset, consumer_id, on_conflict: :nothing),
               {:ok, person} <- get_by_unique(person) do
            {:created, {:ok, person}}
          end

        {:ok, _} ->
          {:error, :has_already_been_taken}
      end
    end
  end

  def update(id, params, consumer_id) do
    with %Person{} = person <- get_by_id(id),
         :ok <- person_is_active(person),
         params = Map.put(params, "updated_by", consumer_id),
         %Changeset{valid?: true} = changeset <- changeset(person, params),
         {:ok, person} <- Repo.update_and_log(changeset, consumer_id) do
      {:ok, person}
    end
  end

  def reset_auth_method(id, params, consumer_id) do
    params = Map.put(params, "updated_by", consumer_id)

    with %Person{status: @person_status_active} = person <- get_by_id(id),
         %Changeset{valid?: true} = changeset <- changeset(person, params),
         {:ok, %Person{} = person} <- Repo.update_and_log(changeset, consumer_id) do
      {:ok, person}
    else
      %Person{} -> {:error, {:conflict, "Invalid status MPI for this action"}}
      err -> err
    end
  end

  # Used only for graphql
  def ql_search(filter, order_by, cursor) do
    Person
    |> preload(^Person.preload_fields())
    |> filter(filter)
    |> apply_cursor(cursor)
    |> order_by(^order_by)
    |> @read_repo.all()
  rescue
    _ in Postgrex.Error ->
      {:query_error, "invalid search characters"}
  end

  def search(params), do: find_persons(params, nil, paginate: true, read_only: true)

  def list(params, fields, ops), do: find_persons(params, fields, ops)

  defp find_persons(params, fields, ops) do
    repo = if ops[:read_only], do: @read_repo, else: Repo
    params = trim_name_spaces(params)
    paging = params |> Map.take(~w(page page_size)) |> repo.paginator_options()

    entries_query =
      params
      |> Search.person_search_query()
      |> person_preload_query(fields)
      |> order_by([p, ...], desc: p.inserted_at)
      |> limit(^paging.page_size)
      |> offset(^((paging.page_number - 1) * paging.page_size))

    count_query = params |> Search.person_search_query() |> select([p], count(p.id))

    if ops[:paginate],
      do: EctoPaginator.paginate(entries_query, count_query, paging),
      else: repo.all(entries_query)
  rescue
    _ in Postgrex.Error ->
      {:query_error, "invalid search characters"}
  end

  defp person_preload_query(query, nil), do: preload(query, ^Person.preload_fields())
  defp person_preload_query(query, fields), do: select(query, ^fields)

  defp person_is_active(%Person{is_active: true, status: @person_status_active}), do: :ok
  defp person_is_active(_), do: {:error, {:conflict, "person is not active"}}

  def get_person_auth_method(person_id) do
    authentication_method =
      PersonAuthenticationMethod
      |> where([am], am.person_id == ^person_id)
      |> order_by([am], desc: am.updated_at)
      |> limit([am], 1)
      |> @read_repo.one()

    if is_nil(authentication_method) do
      with %Person{} = person <- get_by_id(person_id) do
        List.first(person.authentication_methods)
      end
    else
      authentication_method
    end
  end
end
