defmodule MPI.Persons.PersonsAPI do
  @moduledoc false

  import Ecto.{Changeset, Query}
  alias Ecto.Changeset
  alias MPI.Person
  alias MPI.Repo
  alias Scrivener.Page

  def changeset(struct, params) do
    struct
    |> cast(params, Person.fields())
    |> validate_required(Person.fields_required())
  end

  def create(params, consumer_id) do
    search_params = Map.take(params, ~w(last_name first_name birth_date tax_id second_name))

    case search(search_params) do
      %Page{entries: [person]} ->
        with %Changeset{valid?: true} = changeset <- changeset(person, params) do
          {:ok, Repo.update_and_log(changeset, consumer_id)}
        end

      # https://edenlab.atlassian.net/wiki/display/EH/Private.Create+or+update+Person
      %Page{} ->
        with %Changeset{valid?: true} = changeset <- changeset(%Person{}, params) do
          {:created, Repo.insert_and_log(changeset, consumer_id)}
        end

      error ->
        error
    end
  end

  def search(params) do
    paging_params = Map.merge(%{"page_size" => Confex.get_env(:mpi, :max_persons_result)}, params)

    params =
      params
      |> Map.drop(~w(type birth_certificate phone_number ids first_name last_name second_name))
      |> Map.take(Enum.map(Person.__schema__(:fields), &to_string(&1)))

    Person
    |> where([p], ^Enum.into(params, Keyword.new(), fn {k, v} -> {String.to_atom(k), v} end))
    |> where([p], p.is_active)
    |> with_names(Map.take(params, ~w(first_name last_name second_name)))
    |> with_ids(Map.take(params, ~w(ids)))
    |> with_type_number(Map.take(params, ~w(type number)))
    |> with_birth_certificate(Map.take(params, ~w(birth_certificate)))
    |> with_phone_number(Map.take(params, ~w(phone_number)))
    |> Repo.paginate(paging_params)
  end

  defp with_type_number(query, %{"type" => type, "number" => number})
       when type in ~w(tax_id national_id) and not is_nil(number) do
    where(query, [p], field(p, ^type) == ^number)
  end

  defp with_type_number(query, %{"type" => type, "number" => number}) when not is_nil(type) and not is_nil(number) do
    type = String.upcase(type)

    where(query, [p], fragment("? @> ?", p.documents, ~s/[{"type":"#{type}","number":"#{number}"}]/))
  end

  defp with_type_number(query, _), do: query

  defp with_phone_number(query, %{"phone_number" => phone_number}) do
    where(query, [p], fragment("? @> ?", p.phones, ~s/[{"type":"MOBILE","number":"#{phone_number}"}]/))
  end

  defp with_phone_number(query, _), do: query

  defp with_birth_certificate(query, %{"birth_certificate" => birth_certificate}) when not is_nil(birth_certificate) do
    where(
      query,
      [p],
      fragment("? @> ?", p.documents, ~s/[{"type":"BIRTH_CERTIFICATE","number":"#{birth_certificate}"}]/)
    )
  end

  defp with_birth_certificate(query, _), do: query

  defp with_names(query, params) do
    Enum.reduce(params, query, fn {key, value} ->
      where(query, [p], fragment("lower(?)", field(p, ^key)) == ^String.downcase(value))
    end)
  end

  defp with_ids(query, %{"ids" => ids}) do
    where(query, [p], p.id in ^String.split(ids, ","))
  end

  defp with_ids(query, _), do: query
end
