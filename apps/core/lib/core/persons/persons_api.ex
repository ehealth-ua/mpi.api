defmodule Core.Persons.PersonsAPI do
  @moduledoc false

  import Ecto.Changeset
  import Ecto.Query
  alias Core.Person
  alias Core.PersonDocument
  alias Core.PersonPhone
  alias Core.PersonUpdate
  alias Core.Repo
  alias Ecto.Changeset

  @person_status_active Person.status(:active)

  def changeset(%Person{} = person, params) do
    person
    |> Repo.preload([:phones, :documents])
    |> cast(params, Person.fields())
    |> cast_assoc(:phones)
    |> cast_assoc(:documents, required: true)
    # TODO: cast national id according  to new rules in feature
    # |> cast_national_id(params)
    |> validate_required(Person.fields_required())
    |> unique_constraint(:last_name, name: :persons_first_name_last_name_second_name_tax_id_birth_date_inde)
  end

  defp cast_national_id(%Changeset{changes: changes = %{national_id: nil}} = changeset, params),
    do: cast_national_id(%{changeset | changes: Map.delete(changes, :national_id)}, params)

  defp cast_national_id(changeset, %{"national_id" => national_id})
       when not is_nil(national_id),
       do: cast(changeset, %{national_id: national_id}, [:national_id])

  defp cast_national_id(%Changeset{changes: %{documents: documents}} = changeset, _) do
    case get_national_id(documents) do
      nil ->
        changeset

      national_id ->
        cast(changeset, %{national_id: national_id}, [:national_id])
    end
  end

  defp cast_national_id(changes, _), do: changes

  defp get_national_id([]), do: nil
  defp get_national_id([%Changeset{changes: %{type: "NATIONAL_ID", number: national_id}} | _]), do: national_id
  defp get_national_id([_ | documents]), do: get_national_id(documents)

  def get_by_id(id) do
    Person
    |> where([p], p.id == ^id)
    |> preload([:phones, :documents])
    |> Repo.one()
  end

  def create(%{"id" => id} = params, consumer_id) when is_binary(id) do
    params = Map.put(params, "updated_by", consumer_id)

    with %Person{is_active: true, status: @person_status_active} = person <- get_by_id(id),
         %Changeset{valid?: true} = changeset <- changeset(person, Map.delete(params, "id")),
         {:ok, result} <-
           Repo.transaction(fn ->
             case fetch_change(changeset, :status) do
               {:ok, new_status} ->
                 Repo.insert(%PersonUpdate{
                   person_id: id,
                   updated_by: consumer_id,
                   updated_at: DateTime.utc_now(),
                   status: new_status
                 })

               _ ->
                 nil
             end

             Repo.update_and_log(changeset, consumer_id)
           end) do
      {:ok, result}
    else
      %Person{is_active: false} -> {:error, {:conflict, "person is not active"}}
      %Person{status: _} -> {:error, {:conflict, "person is not active"}}
      error -> error
    end
  end

  def create(params, consumer_id) do
    params = Map.merge(params, %{"inserted_by" => consumer_id, "updated_by" => consumer_id})

    with %Changeset{valid?: true} = changeset <- changeset(%Person{}, params),
         {:ok, person} <-
           Repo.transaction(fn ->
             with {:ok, person} <- Repo.insert_and_log(changeset, consumer_id) do
               Repo.insert(%PersonUpdate{
                 person_id: person.id,
                 updated_by: consumer_id,
                 updated_at: DateTime.utc_now(),
                 status: person.status
               })

               person
             else
               {:error, error} ->
                 Repo.rollback(error)
             end
           end) do
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
         {:ok, person} <-
           Repo.transaction(fn ->
             case fetch_change(changeset, :status) do
               {:ok, new_status} ->
                 Repo.insert(%PersonUpdate{
                   person_id: id,
                   updated_by: consumer_id,
                   updated_at: DateTime.utc_now(),
                   status: new_status
                 })

               _ ->
                 nil
             end

             with {:ok, person} <- Repo.update_and_log(changeset, consumer_id) do
               person
             end
           end) do
      {:ok, person}
    end
  end

  def reset_auth_method(id, params, consumer_id) do
    params = Map.put(params, "updated_by", consumer_id)

    with %Person{status: @person_status_active} = person <- get_by_id(id),
         %Changeset{valid?: true} = changeset <- changeset(person, params),
         {:ok, %Person{} = person} <- Repo.update_and_log(changeset, consumer_id) do
      {:ok, person}
    end
  end

  def search(params) do
    paging_params = Map.merge(%{"page_size" => Confex.get_env(:core, :max_persons_result)}, params)

    direct_params =
      params
      |> Map.drop(~w(type birth_certificate phone_number ids first_name last_name second_name))
      |> Map.take(Enum.map(Person.__schema__(:fields), &to_string(&1)))

    subquery =
      Person
      |> where([p], ^Enum.into(direct_params, Keyword.new(), fn {k, v} -> {String.to_atom(k), v} end))
      |> where([p], p.is_active)
      |> with_names(Map.take(params, ~w(first_name last_name second_name)))
      |> with_ids(Map.take(params, ~w(ids)))
      |> with_type_number(Map.take(params, ~w(type number)))
      |> with_birth_certificate(Map.take(params, ~w(birth_certificate)))
      |> with_phone_number(Map.take(params, ~w(phone_number)))

    try do
      Person
      |> preload([:documents, :phones])
      |> join(:inner, [p], s in subquery(subquery), p.id == s.id)
      |> Repo.paginate(paging_params)
    rescue
      _ in Postgrex.Error ->
        {:query_error, "invalid search characters"}
    end
  end

  defp with_type_number(query, %{"type" => type, "number" => number})
       when type in ~w(tax_id national_id) and not is_nil(number) do
    where(query, [p], field(p, ^String.to_atom(type)) == ^number)
  end

  defp with_type_number(query, %{"type" => type, "number" => number}) when not is_nil(type) and not is_nil(number) do
    type = String.upcase(type)
    join(query, :inner, [p], d in PersonDocument, d.person_id == p.id and d.type == ^type and d.number == ^number)
  end

  defp with_type_number(query, _), do: query

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

  defp with_birth_certificate(query, %{"birth_certificate" => birth_certificate}) when not is_nil(birth_certificate) do
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
end