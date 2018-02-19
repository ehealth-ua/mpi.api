defmodule MPI.Persons.PersonsAPI do
  @moduledoc false

  import Ecto.{Changeset, Query}
  alias MPI.{Repo, Person}

  @inactive_statuses ~w(INACTIVE MERGED)

  def changeset(:internal, params) do
    types = %{type: :string, number: :string}

    {%{}, types}
    |> cast(params, Map.keys(types))
    |> validate_required(Map.keys(types))
  end

  def changeset(struct, params) do
    struct
    |> cast(params, Person.fields())
    |> validate_required(Person.fields_required())
  end

  def search(%Ecto.Changeset{changes: parameters}, params, all \\ false) do
    params = Map.merge(%{"page_size" => Confex.get_env(:mpi, :max_persons_result)}, params)

    parameters
    |> prepare_ids()
    |> prepare_case_insensitive_fields()
    |> get_query(all)
    |> Repo.paginate(params)
  end

  def search_internal(%Ecto.Changeset{valid?: true, changes: changes}, params) do
    changes
    |> get_query(false)
    |> Repo.paginate(params)
  end

  def get_query(%{type: type, number: number} = changes, all) when type in ~w(tax_id national_id) do
    changes
    |> Map.drop(~w(type number)a)
    |> Map.put(String.to_atom(type), number)
    |> get_query(all)
  end

  def get_query(%{type: type} = changes, all) do
    type = String.upcase(type)

    changes
    |> Map.drop(~w(type number)a)
    |> get_query(all)
    |> where([p], fragment("? @> ?", p.documents, ~s/[{"type":"#{type}","number":"#{changes.number}"}]/))
  end

  def get_query(%{phone_number: phone_number} = changes, all) do
    changes
    |> Map.delete(:phone_number)
    |> get_query(all)
    |> where([p], fragment("? @> ?", p.phones, ~s/[{"type":"MOBILE","number":"#{phone_number}"}]/))
  end

  def get_query(changes, all) do
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
