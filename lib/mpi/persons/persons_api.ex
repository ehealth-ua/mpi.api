defmodule MPI.Persons.PersonsAPI do
  @moduledoc false

  import Ecto.Changeset
  import Ecto.Query
  alias MPI.Repo
  alias MPI.Person

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
    |> get_query()
    |> Repo.page(%Ecto.Paging{limit: limit, cursors: cursors})
  end

  def get_query(%{phone_number: phone_number} = changes) do
    params =
      changes
      |> Map.delete(:phone_number)
      |> Map.to_list()

    from s in MPI.Person,
      where: ^params,
      where: fragment("? @> ?", s.phones, ~s/[{"type":"MOBILE","number":"#{phone_number}"}]/)
  end

  def get_query(changes) do
    params = Enum.filter(changes, fn({_key, value}) -> !is_tuple(value) end)

    q = from s in MPI.Person,
      where: ^params

    Enum.reduce(changes, q, fn({key, val}, query) ->
      case val do
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
end
