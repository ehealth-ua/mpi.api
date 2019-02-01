defmodule Deduplication.V2.PythonWorker do
  @moduledoc """
  Workers connected to running Python3 instances
  """

  use GenServer

  @app_name :deduplication
  @python_app_dir "python"
  @python_model "model_boosted_without_registration.sav"
  @python_woe_dict "woe_boosted_without_registration.sav"

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  def init(_) do
    with {:ok, priv_dir_path} <- get_priv_dir_path(@app_name),
         python_app_path = Path.join(priv_dir_path, @python_app_dir),
         {:ok, python} <- start_python(python_app_path),
         {:ok, model_bin} <- File.read(Path.join(python_app_path, @python_model)),
         {:ok, woe_dict_bin} <- File.read(Path.join(python_app_path, @python_woe_dict)),
         do: {:ok, {python, woe_dict_bin, model_bin}}
  end

  def handle_call({:weight, bin_map}, _from, {python, woe_dict_bin, model_bin} = state) do
    bin_list =
      bin_map
      |> Map.drop([:person_id, :candidate_id])
      |> Map.to_list()

    with {:ok, res} <- call_python(python, [bin_list, woe_dict_bin, model_bin]),
         do: {:reply, res, state}
  end

  def terminate(_reason, {python, _}) do
    stop_python(python)
  end

  defp start_python(python_app_path) when is_binary(python_app_path) do
    with {:ok, python} <-
           :python.start(python_path: String.to_charlist(python_app_path), python: 'python3'),
         do: {:ok, python}
  end

  defp call_python(python, args) when is_pid(python) and is_list(args) do
    with {:ok, res} <- :python.call(python, :model, :weight, args),
         do: {:ok, res}
  rescue
    e in ErlangError -> {:error, Map.get(e, :original)}
  end

  defp stop_python(python) when is_pid(python), do: :python.stop(python)

  defp get_priv_dir_path(app_name) do
    case :code.priv_dir(app_name) do
      {:error, error} -> {:error, error}
      priv_dir_path when is_list(priv_dir_path) -> {:ok, to_string(priv_dir_path)}
    end
  end
end
