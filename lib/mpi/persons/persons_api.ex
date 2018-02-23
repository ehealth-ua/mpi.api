defmodule MPI.Persons.PersonsAPI do
  @moduledoc false

  import Ecto.{Changeset, Query}
  alias Ecto.Changeset
  alias MPI.Person
  alias MPI.Persons.Search.Public
  alias MPI.Persons.Search.Admin
  alias MPI.Repo
  alias Scrivener.Page

  @inactive_statuses ~w(INACTIVE MERGED)

  def changeset(struct, params) do
    struct
    |> cast(params, Person.fields())
    |> validate_required(Person.fields_required())
  end

  def create(params, consumer_id) do
    search_params = Map.take(params, ~w(last_name first_name birth_date tax_id second_name))

    case search(search_params, :public) do
      %{paging: %Page{entries: [person]}} ->
        with %Changeset{valid?: true} = changeset <- changeset(person, params) do
          {:ok, Repo.update_and_log(changeset, consumer_id)}
        end

      # https://edenlab.atlassian.net/wiki/display/EH/Private.Create+or+update+Person
      %{paging: %Page{}} ->
        with %Changeset{valid?: true} = changeset <- changeset(%Person{}, params) do
          {:created, Repo.insert_and_log(changeset, consumer_id)}
        end

      error ->
        error
    end
  end

  @doc """
  Default search, used for public persons search
  """
  def search(params, :public) do
    with %Changeset{valid?: true, changes: changes} <- Public.changeset(params) do
      %{changes: changes, paging: do_search(changes, params, false)}
    end
  end

  @doc """
  Used for preload persons search, doesn't filter by status or is_active fields
  """
  def search(params, :public_all) do
    with %Changeset{valid?: true, changes: changes} <- Public.changeset(params) do
      %{changes: changes, paging: do_search(changes, params, true)}
    end
  end

  @doc """
  Admin search, allows to search by tax_id or national_id
  """
  def search(params, :admin) do
    with %Changeset{valid?: true, changes: changes} <- Admin.changeset(params) do
      %{changes: changes, paging: do_search(changes, params)}
    end
  end

  defp do_search(changes, params, all) do
    params = Map.merge(%{"page_size" => Confex.get_env(:mpi, :max_persons_result)}, params)

    changes
    |> prepare_ids()
    |> prepare_case_insensitive_fields()
    |> get_query(all)
    |> Repo.paginate(params)
  end

  defp do_search(changes, params) do
    changes
    |> get_query(false)
    |> Repo.paginate(params)
  end

  defp get_query(%{type: type, number: number} = changes, all) when type in ~w(tax_id national_id) do
    changes
    |> Map.drop(~w(type number)a)
    |> Map.put(String.to_atom(type), number)
    |> get_query(all)
  end

  defp get_query(%{type: type} = changes, all) do
    type = String.upcase(type)

    changes
    |> Map.drop(~w(type number)a)
    |> get_query(all)
    |> where([p], fragment("? @> ?", p.documents, ~s/[{"type":"#{type}","number":"#{changes.number}"}]/))
  end

  defp get_query(%{phone_number: phone_number} = changes, all) do
    changes
    |> Map.delete(:phone_number)
    |> get_query(all)
    |> where([p], fragment("? @> ?", p.phones, ~s/[{"type":"MOBILE","number":"#{phone_number}"}]/))
  end

  defp get_query(changes, all) do
    params = Enum.filter(changes, fn {_key, value} -> !is_tuple(value) end)

    q =
      Person
      |> where([p], ^params)
      |> add_is_active_query(all)
      |> add_status_query(all)

    Enum.reduce(changes, q, fn {key, val}, query ->
      case val do
        {value, :lower} -> where(query, [r], fragment("lower(?)", field(r, ^key)) == ^String.downcase(value))
        {value, :like} -> where(query, [r], ilike(field(r, ^key), ^("%" <> value <> "%")))
        {value, :in} -> where(query, [r], field(r, ^key) in ^value)
        _ -> query
      end
    end)
  end

  defp add_is_active_query(query, true), do: query
  defp add_is_active_query(query, false), do: where(query, [p], p.is_active)

  defp add_status_query(query, true), do: query
  defp add_status_query(query, false), do: where(query, [p], p.status not in ^@inactive_statuses)

  def prepare_ids(%{ids: _} = params) do
    convert_comma_params_to_where_in_clause(params, :ids, :id)
  end

  def prepare_ids(params), do: params

  def convert_comma_params_to_where_in_clause(changes, param_name, db_field) do
    changes
    |> Map.put(db_field, {String.split(changes[param_name], ","), :in})
    |> Map.delete(param_name)
  end

  def prepare_case_insensitive_fields(params) do
    fields = [:first_name, :last_name, :second_name]

    params
    |> Enum.map(fn {k, v} ->
      case k in fields do
        true -> {k, {v, :lower}}
        false -> {k, v}
      end
    end)
    |> Enum.into(%{})
  end
end
