defmodule Core.ModelCase do
  @moduledoc """
  This module defines the test case to be used by
  model tests.
  You may define functions here to be used as helpers in
  your model tests. See `errors_on/2`'s definition as reference.
  Finally, if the test case interacts with the database,
  it cannot be async. For this reason, every test runs
  inside a transaction which is reset at the beginning
  of the test unless the test case is marked as async.
  """

  use ExUnit.CaseTemplate
  alias Ecto.Adapters.SQL.Sandbox
  alias Core.DeduplicationRepo
  alias Core.Repo
  alias Core.ReadRepo

  using do
    quote do
      alias Core.Repo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Core.ModelCase
      import Mox
    end
  end

  setup tags do
    :ok = Sandbox.checkout(Repo)
    :ok = Sandbox.checkout(ReadRepo)
    :ok = Sandbox.checkout(DeduplicationRepo)

    unless tags[:async] do
      Sandbox.mode(Repo, {:shared, self()})
      Sandbox.mode(ReadRepo, {:shared, self()})
      Sandbox.mode(DeduplicationRepo, {:shared, self()})
    end

    :ok
  end

  @doc """
  Helper for returning list of errors in a struct when given certain data.
  ## Examples
  Given a User schema that lists `:name` as a required field and validates
  `:password` to be safe, it would return:
      iex> errors_on(%User{}, %{password: "password"})
      [password: "is unsafe", name: "is blank"]
  You could then write your assertion like:
      assert {:password, "is unsafe"} in errors_on(%User{}, %{password: "password"})
  """
  def errors_on(struct, data) do
    data
    |> (&struct.__struct__.changeset(struct, &1)).()
    |> Enum.flat_map(fn {key, errors} -> for msg <- errors, do: {key, msg} end)
  end
end
