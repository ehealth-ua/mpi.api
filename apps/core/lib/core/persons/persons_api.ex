defmodule Core.Persons.PersonsAPI do
  @moduledoc false

  import Core.Persons.Filter, only: [filter: 2]
  import Core.Query, only: [apply_cursor: 2]
  import Ecto.Changeset
  import Ecto.Query

  alias Core.Maybe
  alias Core.Person
  alias Core.PersonDocument
  alias Core.PersonPhone
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
    person
    |> cast(trim_name_spaces(params), Person.fields())
    |> cast_assoc(:addresses)
    |> cast_assoc(:phones)
    |> cast_assoc(:documents, required: true)
    |> validate_required(Person.fields_required())
    |> unique_constraint(:last_name, name: :persons_uniq_index)
  end

  def get_by_id(id) do
    Person
    |> where([p], p.id == ^id)
    |> join(:left, [p], phones in assoc(p, :phones), as: :phones)
    |> join(:left, [p], d in assoc(p, :documents), as: :documents)
    |> join(:left, [p], a in assoc(p, :addresses), as: :addresses)
    |> join(:left, [p], mp in assoc(p, :merged_persons), as: :merged_persons)
    |> join(:left, [p], m in assoc(p, :master_person), as: :master_person)
    |> preload(
      [
        phones: phones,
        documents: documents,
        addresses: addresses,
        merged_persons: merged_persons,
        master_person: master_person
      ],
      phones: phones,
      documents: documents,
      addresses: addresses,
      merged_persons: merged_persons,
      master_person: master_person
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

    with %Changeset{valid?: true} = changeset <- changeset(%Person{}, params),
         {:ok, person} <- Repo.insert_and_log(changeset, consumer_id),
         %Person{} = person <- get_by_id(person.id) do
      {:created, {:ok, person}}
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
    paging = params |> Map.take(~w(page_size page_number)) |> paging_params()
    fields = fields || Person.preload_fields()
    repo = if ops[:read_only], do: @read_repo, else: Repo

    persons_query =
      params
      |> person_search_query()
      |> person_preload_query(fields)

    persons_data =
      if ops[:paginate] do
        repo.paginate(persons_query, paging)
      else
        persons_query
        |> order_by([p, ...], desc: p.inserted_at)
        |> limit(^paging.page_size)
        |> offset(^(paging.page_number * paging.page_size))
        |> repo.all()
      end

    persons = if ops[:paginate], do: persons_data.entries, else: persons_data

    if [] == persons and not is_nil(params["unzr"]) and not Enum.empty?(Map.delete(params, "unzr")) do
      find_persons(Map.delete(params, "unzr"), fields, ops)
    else
      persons_data
    end
  rescue
    _ in Postgrex.Error ->
      {:query_error, "invalid search characters"}
  end

  defp person_preload_query(query, fields) do
    {preloads, selects} = Enum.split_with(fields, &(&1 in Person.preload_fields()))
    query = if Enum.empty?(preloads), do: query, else: preload(query, ^preloads)
    if Enum.empty?(selects), do: query, else: select(query, ^selects)
  end

  defp person_search_query(%{"unzr" => unzr}) do
    where(Person, [p], p.unzr == ^unzr and p.status == @person_status_active and p.is_active)
  end

  defp person_search_query(params) do
    params = trim_name_spaces(params)

    direct_params =
      params
      |> Map.drop(~w(type birth_certificate phone_number ids first_name last_name second_name))
      |> Map.take(Enum.map(Person.fields(), &to_string(&1)))

    Person
    |> where([p], ^Enum.into(direct_params, Keyword.new(), fn {k, v} -> {String.to_atom(k), v} end))
    |> where([p], p.is_active)
    |> with_names(Map.take(params, ~w(first_name last_name second_name)))
    |> with_ids(Map.take(params, ~w(ids)))
    |> with_type_number(Map.take(params, ~w(type number)))
    |> with_birth_certificate(Map.take(params, ~w(birth_certificate)))
    |> with_phone_number(Map.take(params, ~w(phone_number)))
    |> with_auth_phone_number(Map.take(params, ~w(auth_phone_number)))
    |> with_documents(Map.take(params, ~w(documents)))
  end

  defp with_type_number(query, %{"type" => type, "number" => number})
       when type in ~w(tax_id unzr) and not is_nil(number) do
    where(query, [p], field(p, ^String.to_atom(type)) == ^number)
  end

  defp with_type_number(query, %{"type" => type, "number" => number})
       when not is_nil(type) and not is_nil(number) do
    type = String.upcase(type)

    join(query, :inner, [p], d in PersonDocument,
      on: d.person_id == p.id and d.type == ^type and fragment("lower(?) = lower(?)", d.number, ^number)
    )
  end

  defp with_type_number(query, _), do: query

  defp with_documents(query, %{"documents" => []}), do: query

  defp with_documents(query, %{"documents" => [document | documents]}) do
    query = join(query, :inner, [p], d in PersonDocument, on: d.person_id == p.id)
    documents_query = document_search_query(document)

    documents_query =
      Enum.reduce(documents, documents_query, fn document, acc ->
        dynamic([p, d], ^acc or ^document_search_query(document))
      end)

    query
    |> from()
    |> where(^documents_query)
    |> distinct(true)
  end

  defp with_documents(query, _), do: query

  defp document_search_query(%{"type" => "BIRTH_CERTIFICATE" = type, "digits" => digits}) do
    dynamic([p, d], d.type == ^type and fragment("regexp_replace(number,'[^[:digit:]]','', 'g') = ?", ^digits))
  end

  defp document_search_query(%{"type" => type, "number" => number}) do
    dynamic([p, d], d.type == ^type and fragment("lower(?) = lower(?)", d.number, ^number))
  end

  defp with_phone_number(query, %{"phone_number" => phone_number}) do
    join(query, :inner, [p], ph in PersonPhone,
      on: ph.person_id == p.id and ph.type == "MOBILE" and ph.number == ^phone_number
    )
  end

  defp with_phone_number(query, _), do: query

  defp with_auth_phone_number(query, %{"auth_phone_number" => auth_phone_number}) do
    query
    |> where([p], p.status == @person_status_active)
    |> where([p], fragment("? @> ?", p.authentication_methods, ^[%{"phone_number" => auth_phone_number}]))
  end

  defp with_auth_phone_number(query, _), do: query

  defp with_birth_certificate(query, %{"birth_certificate" => birth_certificate}) when not is_nil(birth_certificate) do
    join(query, :inner, [p], d in PersonDocument,
      on: d.person_id == p.id and d.type == "BIRTH_CERTIFICATE" and d.number == ^birth_certificate
    )
  end

  defp with_birth_certificate(query, _), do: query

  defp with_names(query, params) do
    Enum.reduce(params, query, fn {key, value}, query ->
      where(query, [p], fragment("lower(?)", field(p, ^String.to_atom(key))) == ^String.downcase(value))
    end)
  end

  defp with_ids(query, %{"ids" => ids}) when ids != "", do: where(query, [p], p.id in ^String.split(ids, ","))
  defp with_ids(query, _), do: query

  defp person_is_active(%Person{is_active: true, status: @person_status_active}), do: :ok
  defp person_is_active(_), do: {:error, {:conflict, "person is not active"}}

  defp paging_params(params) do
    max_persons_result = Confex.get_env(:core, :max_persons_result)
    page_number = params["page_number"] || 0

    page_size =
      case params |> Map.get("page_size", "") |> to_string() |> Integer.parse() do
        :error -> max_persons_result
        {value, _} -> min(value, Repo.max_page_size())
      end

    %{page_number: page_number, page_size: page_size}
  end

  def get_person_auth_method(%Person{authentication_methods: authentication_methods}) do
    List.first(authentication_methods)
  end
end
