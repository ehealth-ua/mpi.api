defmodule Deduplication.V2.PythonWorker do
  @moduledoc """
  Workers connected to running Python3 instances
  """

  use GenServer

  @app_name :deduplication
  @python_app_dir "python"
  @python_model_file "model_not_scaled_boosted.sav"

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, [])
  end

  def init(_) do
    with {:ok, priv_dir_path} <- get_priv_dir_path(@app_name),
         python_app_path = Path.join(priv_dir_path, @python_app_dir),
         {:ok, python} <- start_python(python_app_path),
         {:ok, python_model} <- File.read(Path.join(python_app_path, @python_model_file)),
         do: {:ok, {python, python_model}}
  end

  def handle_call({:weight, model}, _from, {python, python_model} = state) when is_map(model) do
    %{
      d_first_name_woe: d_first_name_woe,
      d_last_name_woe: d_last_name_woe,
      d_second_name_woe: d_second_name_woe,
      d_documents_woe: d_documents_woe,
      docs_same_number_woe: docs_same_number_woe,
      birth_settlement_substr_woe: birth_settlement_substr_woe,
      d_tax_id_woe: d_tax_id_woe,
      authentication_methods_flag_woe: authentication_methods_flag_woe,
      residence_settlement_flag_woe: residence_settlement_flag_woe,
      registration_address_settlement_flag_woe: registration_address_settlement_flag_woe,
      gender_flag_woe: gender_flag_woe,
      twins_flag_woe: twins_flag_woe
    } = model

    with {:ok, res} <-
           call_python(python, [
             python_model,
             d_first_name_woe,
             d_last_name_woe,
             d_second_name_woe,
             d_documents_woe,
             docs_same_number_woe,
             birth_settlement_substr_woe,
             d_tax_id_woe,
             authentication_methods_flag_woe,
             residence_settlement_flag_woe,
             registration_address_settlement_flag_woe,
             gender_flag_woe,
             twins_flag_woe
           ]),
         do: {:reply, res, state}
  end

  def terminate(_reason, {python, _}) do
    stop_python(python)
  end

  defp start_python(python_app_path) when is_binary(python_app_path) do
    with {:ok, python} <- :python.start(python_path: String.to_charlist(python_app_path), python: 'python3'),
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
