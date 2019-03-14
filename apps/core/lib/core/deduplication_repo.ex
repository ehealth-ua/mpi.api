defmodule Core.DeduplicationRepo do
  @moduledoc false

  use Ecto.Repo, otp_app: :core, adapter: Ecto.Adapters.Postgres
  use Scrivener, page_size: 50, max_page_size: 500, options: [allow_out_of_range_pages: true]
  use EctoTrail, schema: Core.ManualMerge.AuditLog

  import Ecto.Query

  alias Core.ManualMerge.AuditLog

  @typep schema_or_source :: binary | {binary | nil, binary} | atom

  def set_runtime_params(conn) do
    config = Confex.get_env(@otp_app, __MODULE__, [])
    params = Keyword.get(config, :runtime_params, [])

    do_set_runtime_params(conn, params)
  end

  defp do_set_runtime_params(_, []), do: :ok

  defp do_set_runtime_params(conn, [{name, value} | tail]) do
    Postgrex.query!(conn, "SELECT set_config($1, $2, false)", [name, value])
    do_set_runtime_params(conn, tail)
  end

  @doc """
  Inserts all entries into the repository and creates audit_log.
  """
  @spec insert_all_and_log(schema_or_source, [map | Keyword.t()], binary(), Keyword.t()) :: {integer(), nil | [term()]}
  def insert_all_and_log(schema_or_source, entries, actor_id, opts \\ []) do
    opts = Keyword.put_new(opts, :returning, [:id])

    schema_or_source
    |> insert_all(entries, opts)
    |> create_audit_logs(entries, actor_id)
  end

  @doc """
  Updates all entries matching the given query with the given values and creates audit_log.
  """
  @spec update_all_and_log(Ecto.Queryable.t(), Keyword.t(), binary(), Keyword.t()) :: {integer(), nil | [term()]}
  def update_all_and_log(queryable, updates, actor_id, opts \\ []) do
    queryable
    |> select([v], [:id])
    |> update_all(updates, opts)
    |> create_audit_logs(updates[:set], actor_id)
  end

  defp create_audit_logs({_, []} = result, _changeset, _actor_id), do: result

  defp create_audit_logs({_, updated_entries} = result, changeset, actor_id) do
    changes =
      Enum.map(updated_entries, fn entry ->
        %{
          actor_id: actor_id,
          changeset: Enum.into(changeset, %{}),
          resource: get_source(entry),
          resource_id: entry.id,
          inserted_at: DateTime.utc_now()
        }
      end)

    insert_all(AuditLog, changes)

    result
  end

  defp get_source(source) when is_binary(source), do: source
  defp get_source(%{__struct__: struct}), do: struct.__schema__(:source)
end
