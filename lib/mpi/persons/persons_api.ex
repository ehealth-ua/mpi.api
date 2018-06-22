defmodule MPI.Persons.PersonsAPI do
  @moduledoc false

  import Ecto.{Changeset, Query}
  alias Ecto.Changeset
  alias MPI.{Repo, Person, PersonDocument, PersonPhone}

  @person_status_active Person.status(:active)

  def changeset(%Person{} = person, params) do
    person_changeset =
      person
      |> cast(params, Person.fields())
      |> validate_required(Person.fields_required())
      |> unique_constraint(:last_name, name: :persons_first_name_last_name_second_name_tax_id_birth_date_inde)

    with %Changeset{valid?: true} <- person_changeset,
         person <- apply_changes(person_changeset) do
      person_changeset
      |> cast(
        %{
          person_documents: person.documents,
          person_phones: person.phones || []
        },
        []
      )
      |> cast_assoc(:person_phones)
      |> cast_assoc(:person_documents)
    end
  end

  def get_by_id(id) do
    Person
    |> where([p], p.id == ^id)
    |> preload([:person_phones, :person_documents])
    |> Repo.one()
  end

  def create(%{"id" => id} = params, consumer_id) when is_binary(id) do
    with %Person{is_active: true, status: @person_status_active} = person <- get_by_id(id),
         %Changeset{valid?: true} = changeset <- changeset(person, Map.delete(params, "id")) do
      {:ok, Repo.update_and_log(changeset, consumer_id)}
    else
      %Person{is_active: false} -> {:error, {:conflict, "person is not active"}}
      %Person{status: _} -> {:error, {:conflict, "person is not active"}}
      error -> error
    end
  end

  def create(params, consumer_id) do
    with %Changeset{valid?: true} = changeset <- changeset(%Person{}, params),
         {:ok, person} <- Repo.insert_and_log(changeset, consumer_id) do
      {:created, {:ok, person}}
    end
  end

  def search(params) do
    paging_params = Map.merge(%{"page_size" => Confex.get_env(:mpi, :max_persons_result)}, params)

    direct_params =
      params
      |> Map.drop(~w(type birth_certificate phone_number ids first_name last_name second_name))
      |> Map.take(Enum.map(Person.__schema__(:fields), &to_string(&1)))

    try do
      Person
      |> where([p], ^Enum.into(direct_params, Keyword.new(), fn {k, v} -> {String.to_atom(k), v} end))
      |> where([p], p.is_active)
      |> with_names(Map.take(params, ~w(first_name last_name second_name)))
      |> with_ids(Map.take(params, ~w(ids)))
      |> with_type_number(Map.take(params, ~w(type number)))
      |> with_birth_certificate(Map.take(params, ~w(birth_certificate)))
      |> with_phone_number(Map.take(params, ~w(phone_number)))
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
end
