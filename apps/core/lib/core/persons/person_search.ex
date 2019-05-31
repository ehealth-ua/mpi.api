defmodule Core.Persons.Search do
  @moduledoc false
  import Ecto.Query

  alias Core.Person
  alias Core.PersonAuthenticationMethod
  alias Core.PersonDocument
  alias Core.PersonPhone

  @person_status_active Person.status(:active)

  def person_search_query(params) do
    custom_params = ~w(birth_certificate phone_number ids first_name last_name second_name auth_phone_number documents)

    direct_params = params |> Map.drop(custom_params) |> Map.take(Enum.map(Person.fields(), &to_string(&1)))
    params = params |> Map.take(custom_params) |> simplify_documents_params()

    Person
    |> where([p], ^Enum.into(direct_params, Keyword.new(), fn {k, v} -> {String.to_atom(k), v} end))
    |> with_names(Map.take(params, ~w(first_name last_name second_name)))
    |> with_ids(Map.take(params, ~w(ids)))
    |> with_phone_number(Map.take(params, ~w(phone_number)))
    |> with_auth_phone_number(Map.take(params, ~w(auth_phone_number)))
    |> with_documents(Map.take(params, ~w(documents)))
    |> where([p], p.is_active)
  end

  defp simplify_documents_params(params) do
    birth_certificate = params["birth_certificate"]
    documents = params["documents"] || []

    params =
      if birth_certificate do
        documents = [%{"type" => "BIRTH_CERTIFICATE", "number" => birth_certificate} | documents]
        params |> Map.delete("birth_certificate") |> Map.put("documents", documents)
      else
        params
      end
  end

  defp with_documents(query, %{"documents" => [document | documents]}) do
    query = join(query, :inner, [p], d in PersonDocument, on: d.person_id == p.id)
    documents_query = document_search_query(document)

    documents_query =
      Enum.reduce(documents, documents_query, fn document, acc ->
        dynamic([p, d], ^acc or ^document_search_query(document))
      end)

    query
    |> from()
    |> where(^documents_query)
    |> distinct(true)
  end

  defp with_documents(query, _), do: query

  defp document_search_query(%{"type" => "BIRTH_CERTIFICATE" = type, "digits" => digits}) do
    dynamic([p, d], d.type == ^type and fragment("regexp_replace(number,'[^[:digit:]]','','g') = ?", ^digits))
  end

  defp document_search_query(%{"type" => type, "number" => number}) do
    number = String.downcase(number)
    dynamic([p, d], d.type == ^String.upcase(type) and fragment("lower(?) = ?", d.number, ^number))
  end

  defp with_phone_number(query, %{"phone_number" => phone_number}) do
    join(query, :inner, [p], ph in PersonPhone,
      on: ph.person_id == p.id and ph.type == "MOBILE" and ph.number == ^phone_number
    )
  end

  defp with_phone_number(query, _), do: query

  defp with_auth_phone_number(query, %{"auth_phone_number" => auth_phone_number}) do
    query
    |> where([p], p.status == @person_status_active)
    |> join(:inner, [p], am in PersonAuthenticationMethod,
      on: am.person_id == p.id and am.phone_number == ^auth_phone_number
    )
  end

  defp with_auth_phone_number(query, _), do: query

  defp with_names(query, params) do
    Enum.reduce(params, query, fn {key, value}, query ->
      where(query, [p], fragment("lower(?)", field(p, ^String.to_atom(key))) == ^String.downcase(value))
    end)
  end

  defp with_ids(query, %{"ids" => ids}) when ids != "", do: where(query, [p], p.id in ^String.split(ids, ","))
  defp with_ids(query, _), do: query
end
