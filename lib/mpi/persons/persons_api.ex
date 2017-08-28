defmodule MPI.Persons.PersonsAPI do
  @moduledoc false

  import Ecto.Changeset
  import Ecto.Query
  alias MPI.Repo
  alias MPI.Person

  @inactive_statuses ["INACTIVE", "MERGED"]

  def changeset(struct, params \\ %{}) do
    struct
    |> cast(params, Person.fields())
    |> validate_required(Person.fields_required())
  end

  def search(%Ecto.Changeset{changes: parameters}, params) do
    cursors =
      %Ecto.Paging.Cursors{
        starting_after: Map.get(params, "starting_after"),
        ending_before: Map.get(params, "ending_before", nil)
      }

    limit = Map.get(params, "limit", Confex.get_env(:mpi, :max_persons_result))
    parameters
    |> prepare_ids()
    |> prepare_case_insensitive_fields()
    |> get_query()
    |> Repo.page(%Ecto.Paging{limit: limit, cursors: cursors})
  end

  def get_query(%{phone_number: phone_number} = changes) do
    changes
    |> Map.delete(:phone_number)
    |> get_query()
    |> where([p], fragment("? @> ?", p.phones, ~s/[{"type":"MOBILE","number":"#{phone_number}"}]/))
  end

  def get_query(changes) do
    params = Enum.filter(changes, fn({_key, value}) -> !is_tuple(value) end)

    q = from s in MPI.Person,
      where: ^params,
      where: s.is_active,
      where: not s.status in ^@inactive_statuses

    Enum.reduce(changes, q, fn({key, val}, query) ->
      case val do
        {value, :lower} -> where(query, [r], fragment("lower(?)", field(r, ^key)) == ^String.downcase(value))
        {value, :like} -> where(query, [r], ilike(field(r, ^key), ^("%" <> value <> "%")))
        {value, :in} -> where(query, [r], field(r, ^key) in ^value)
        _ -> query
      end
    end)
  end

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
    |> Enum.map(fn ({k, v}) ->
         case k in fields do
           true -> {k, {v, :lower}}
           false -> {k, v}
         end
       end)
    |> Enum.into(%{})
  end
end
