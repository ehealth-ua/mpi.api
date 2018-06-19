defmodule MPI.Repo do
  @moduledoc false
  use Ecto.Repo, otp_app: :mpi
  use Scrivener, page_size: 50, max_page_size: 500
  use EctoTrail

  @doc """
  Dynamically loads the repository url from the
  DATABASE_URL environment variable.
  """
  def init(_, opts) do
    {:ok, Keyword.put(opts, :url, System.get_env("DATABASE_URL"))}
  end
end
