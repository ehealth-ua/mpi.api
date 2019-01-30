defmodule Core.Factory do
  @moduledoc """
  This module lists factories, a mean suitable
  for tests that involve preparation of DB data
  """
  use ExMachina

  use Core.Factories.MPI
  use Core.Factories.Deduplication

  alias Core.Repo
  alias Core.DeduplicationRepo

  def insert(type, factory, attrs \\ []) do
    factory
    |> build(attrs)
    |> repo_insert!(type)
  end

  def insert_list(count, type, factory, attrs \\ []) when count >= 1 do
    for _ <- 1..count, do: insert(type, factory, attrs)
  end

  def string_params_for(factory, attrs \\ %{}) do
    factory
    |> build(attrs)
    |> atoms_to_strings()
  end

  defp repo_insert!(data, :mpi), do: Repo.insert!(data)
  defp repo_insert!(data, :deduplication), do: DeduplicationRepo.insert!(data)

  defp atoms_to_strings(%{} = map), do: map |> Poison.encode!() |> Poison.decode!()
end
