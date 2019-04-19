defmodule Deduplication.PythonWorker do
  @moduledoc """
  Workers connected to running Python3 instances
  """

  use GenServer

  @app_name :deduplication
  @python_app_dir "python"
  @python_model "model_boosted_new_docs.sav"
  @python_woe_dict "woe_boosted_docs.sav"

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  def init(_) do
    with {:ok, priv_dir_path} <- get_priv_dir_path(@app_name),
         python_app_path = Path.join(priv_dir_path, @python_app_dir),
         {:ok, python} <- start_python(python_app_path),
         {:ok, model} <- File.read(Path.join(python_app_path, @python_model)),
         {:ok, woe_dictionary} <- File.read(Path.join(python_app_path, @python_woe_dict)),
         do: {:ok, {python, woe_dictionary, model}}
  end

  def handle_call(
        {:weight,
         %{
           d_first_name_bin: d_first_name_bin,
           d_last_name_bin: d_last_name_bin,
           d_second_name_bin: d_second_name_bin,
           d_documents_bin: d_documents_bin,
           docs_same_number_bin: docs_same_number_bin,
           birth_settlement_substr_bin: birth_settlement_substr_bin,
           d_tax_id_bin: d_tax_id_bin,
           authentication_methods_flag_bin: authentication_methods_flag_bin,
           residence_settlement_flag_bin: residence_settlement_flag_bin,
           gender_flag_bin: gender_flag_bin,
           twins_flag_bin: twins_flag_bin
         }},
        _from,
        {python, woe_dictionary, model} = state
      ) do
    with {:ok, res} <-
           call_python(python, [
             d_first_name_bin,
             d_last_name_bin,
             d_second_name_bin,
             d_documents_bin,
             docs_same_number_bin,
             birth_settlement_substr_bin,
             d_tax_id_bin,
             authentication_methods_flag_bin,
             residence_settlement_flag_bin,
             gender_flag_bin,
             twins_flag_bin,
             woe_dictionary,
             model
           ]),
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
