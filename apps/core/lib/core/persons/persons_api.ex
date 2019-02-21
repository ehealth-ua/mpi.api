defmodule Core.Persons.PersonsAPI do
  @moduledoc false

  import Ecto.Changeset
  import Ecto.Query
  import Core.Query, only: [apply_cursor: 2]

  alias Core.Filters.Base, as: BaseFilter
  alias Core.Maybe
  alias Core.Person
  alias Core.PersonAddress
  alias Core.PersonDocument
  alias Core.PersonPhone
  alias Core.Repo
  alias Ecto.Changeset

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
    person_changes =
      person
      |> Repo.preload([:phones, :documents, :addresses])
      |> cast(trim_name_spaces(params), Person.fields())

    person_changes
    |> cast_assoc(:addresses, with: &PersonAddress.cast_addresses(&1, &2, person_changes, person), required: true)
    |> cast_assoc(:phones)
    |> cast_assoc(:documents, required: true)
    |> validate_required(Person.fields_required())
    |> unique_constraint(:last_name, name: :persons_first_name_last_name_second_name_tax_id_birth_date_inde)
  end

  def get_by_id(id) do
    Person
    |> where([p], p.id == ^id)
    |> preload([:phones, :documents, :addresses])
    |> Repo.one()
  end

  def create(%{"id" => id} = params, consumer_id) when is_binary(id) do
    params = Map.put(params, "updated_by", consumer_id)

    with %Person{is_active: true, status: @person_status_active} = person <- get_by_id(id),
         %Changeset{valid?: true} = changeset <- changeset(person, Map.delete(params, "id")),
         {:ok, person} <- Repo.update_and_log(changeset, consumer_id) do
      {:ok, {:ok, person}}
    else
      %Person{is_active: false} -> {:error, {:conflict, "person is not active"}}
      %Person{status: _} -> {:error, {:conflict, "person is not active"}}
      error -> error
    end
  end

  def create(params, consumer_id) do
    params = Map.merge(params, %{"inserted_by" => consumer_id, "updated_by" => consumer_id})

    with %Changeset{valid?: true} = changeset <- changeset(%Person{}, params),
         {:ok, person} <- Repo.insert_and_log(changeset, consumer_id) do
      {:created, {:ok, person}}
    end
  end

  def update(id, params, consumer_id) do
    with %Person{} = person <- get_by_id(id),
         :ok <- person_is_active(person),
         params =
           person
           |> preprocess_params(params)
           |> Map.put("updated_by", consumer_id),
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

  @doc """
  used only for graphql
  """
  def search(filter, order_by, cursor) do
    Person
    |> preload([:documents, :phones, :addresses])
    |> BaseFilter.filter(filter)
    |> apply_cursor(cursor)
    |> order_by(^order_by)
    |> Repo.all()
  rescue
    _ in Postgrex.Error ->
      {:query_error, "invalid search characters"}
  end

  def search(params, fields \\ nil) do
    paging_params = Map.merge(%{"page_size" => Confex.get_env(:core, :max_persons_result)}, params)

    persons =
      Person
      |> person_preload_query(fields)
      |> join(:inner, [p], s in subquery(person_search_query(params)), p.id == s.id)
      |> order_by([p], desc: p.inserted_at)
      |> Repo.paginate(paging_params)

    if Enum.empty?(persons) and params["unzr"], do: search(Map.delete(params, "unzr")), else: persons
  rescue
    _ in Postgrex.Error ->
      {:query_error, "invalid search characters"}
  end

  defp person_preload_query(Person = query, fields) when is_list(fields), do: select(query, ^fields)
  defp person_preload_query(Person = query, _), do: preload(query, [:documents, :phones, :addresses])

  defp person_search_query(%{"unzr" => unzr}) do
    Person
    |> where([p], p.unzr == ^unzr)
    |> where([p], p.status == @person_status_active)
  end

  defp person_search_query(params) do
    params = trim_name_spaces(params)

    direct_params =
      params
      |> Map.drop(~w(type birth_certificate phone_number ids first_name last_name second_name))
      |> Map.take(Enum.map(Person.__schema__(:fields), &to_string(&1)))

    Person
    |> where(
      [p],
      ^Enum.into(direct_params, Keyword.new(), fn {k, v} -> {String.to_atom(k), v} end)
    )
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

    join(
      query,
      :inner,
      [p],
      d in PersonDocument,
      d.person_id == p.id and d.type == ^type and fragment("lower(?) = lower(?)", d.number, ^number)
    )
  end

  defp with_type_number(query, _), do: query

  defp with_documents(query, %{"documents" => []}), do: query

  defp with_documents(query, %{"documents" => [document | documents]}) do
    query = join(query, :inner, [p], d in PersonDocument, d.person_id == p.id)
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

  defp document_search_query(document) do
    if document["type"] == "BIRTH_CERTIFICATE" and Map.has_key?(document, "digits") do
      dynamic(
        [p, d],
        d.type == ^document["type"] and
          fragment("regexp_replace(number,'[^[:digit:]]','', 'g') = ?", ^document["digits"])
      )
    else
      dynamic([p, d], d.type == ^document["type"] and fragment("lower(?) = lower(?)", d.number, ^document["number"]))
    end
  end

  defp with_phone_number(query, %{"phone_number" => phone_number}) do
    join(
      query,
      :inner,
      [p],
      ph in PersonPhone,
      ph.person_id == p.id and ph.type == "MOBILE" and ph.number == ^phone_number
    )
  end

  defp with_phone_number(query, _), do: query

  defp with_auth_phone_number(query, %{"auth_phone_number" => auth_phone_number}) do
    query
    |> where([p], p.status == @person_status_active)
    |> where(
      [p],
      fragment("? @> ?", p.authentication_methods, ^[%{"phone_number" => auth_phone_number}])
    )
  end

  defp with_auth_phone_number(query, _), do: query

  defp with_birth_certificate(query, %{"birth_certificate" => birth_certificate})
       when not is_nil(birth_certificate) do
    join(
      query,
      :inner,
      [p],
      d in PersonDocument,
      d.person_id == p.id and d.type == "BIRTH_CERTIFICATE" and d.number == ^birth_certificate
    )
  end

  defp with_birth_certificate(query, _), do: query

  defp with_names(query, params) do
    Enum.reduce(params, query, fn {key, value}, query ->
      where(query, [p], fragment("lower(?)", field(p, ^String.to_atom(key))) == ^String.downcase(value))
    end)
  end

  defp with_ids(query, %{"ids" => ids}) when ids != "" do
    where(query, [p], p.id in ^String.split(ids, ","))
  end

  defp with_ids(query, _), do: query

  defp preprocess_params(person, params) do
    existing_merged_ids = person.merged_ids || []
    new_merged_ids = Map.get(params, "merged_ids", [])

    Map.merge(params, %{"merged_ids" => existing_merged_ids ++ new_merged_ids})
  end

  defp person_is_active(%Person{is_active: true}), do: :ok
  defp person_is_active(_), do: {:error, {:"422", "Person is not active"}}

  def get_person_auth_method(%Person{authentication_methods: authentication_methods}) do
    List.first(authentication_methods)
  end
end
