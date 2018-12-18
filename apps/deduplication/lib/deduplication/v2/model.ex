defmodule Deduplication.V2.Model do
  @moduledoc """
  Quering persons and prepare data
  """

  import Ecto.Query

  alias Core.MergeCandidate
  alias Core.Person
  alias Core.PersonAddress
  alias Core.PersonDocument
  alias Core.Repo

  def async_stream_filter(streamlist) do
    Enum.reduce(streamlist, [], fn
      {:ok, :skip}, acc -> acc
      {:ok, v}, acc -> [v | acc]
      _, acc -> acc
    end)
  end

  def normalize_text(nil), do: nil

  def normalize_text(text) do
    r0 = String.downcase(text)
    r1 = Regex.replace(~r/[ \-–—−‐']/iu, r0, "")
    r2 = Regex.replace(~r/є/iu, r1, "е")
    Regex.replace(~r/и/iu, r2, "і")
  end

  def normalize_birth_certificate_document(nil), do: nil

  def normalize_birth_certificate_document(text) do
    dc_str = String.downcase(text)
    norm_str = Regex.replace(~r/[\/\%#№_ \-–—−‐]/iu, dc_str, "")

    Regex.replace(~r/^[iі!IІ]/iu, norm_str, "1")
  end

  def normalize_document_number(nil), do: nil

  def normalize_document_number(text) do
    dc_str = String.downcase(text)
    Regex.replace(~r/[\/\%#№_ \-–—−‐]/iu, dc_str, "")
  end

  def document_number(nil), do: nil

  def document_number(text) do
    case Regex.replace(~r/[^0-9]/iu, text, "") do
      "" -> nil
      text -> text
    end
  end

  def get_unverified_persons(limit, offset) do
    Person
    |> preload([:documents, :addresses])
    |> where([p], is_nil(p.merge_verified))
    |> order_by([p], desc: p.inserted_at)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def match_candidates_query(query, _, nil), do: query

  def match_candidates_query(query, :tax_id, tax_id) do
    or_where(query, [p, m], p.tax_id == ^tax_id)
  end

  def match_candidates_query(query, :auth_phone, auth_phone_number) do
    or_where(
      query,
      [p, m],
      fragment(
        "? @> ?",
        p.authentication_methods,
        ^[%{"phone_number" => auth_phone_number, "type" => "OTP"}]
      )
    )
  end

  @doc """
  Makes 3 query because plan is not optimal for one query
  """
  def get_candidates(%Person{} = person) do
    dq_person_ids =
      PersonDocument
      |> select([d], d.person_id)
      |> distinct(true)
      |> where(
        [d],
        fragment("regexp_replace(?, '[^[:digit:]]', '', 'g' )", d.number) in ^Enum.map(
          person.documents,
          fn %PersonDocument{number: number} -> document_number(number) end
        )
      )
      |> Repo.all()

    pq_dq_person_ids =
      Person
      |> select([p, m], p.id)
      |> distinct(true)
      |> where([p, m], false)
      |> match_candidates_query(:tax_id, person.tax_id)
      |> match_candidates_query(:auth_phone, person_auth_phone(person.authentication_methods))
      |> Repo.all()

    matched_ids = (pq_dq_person_ids ++ dq_person_ids) |> MapSet.new() |> MapSet.to_list()

    if matched_ids == [],
      do: [],
      else:
        Person
        |> distinct(true)
        |> preload([:documents, :addresses])
        |> join(:left, [p, d], m in MergeCandidate, m.master_person_id == p.id)
        |> where(
          [p, m],
          p.id in ^matched_ids and p.id != ^person.id and p.inserted_at <= ^person.inserted_at and
            is_nil(m.master_person_id)
        )
        |> Repo.all()
  end

  def get_candidates(_, _), do: []

  def person_auth_phone(authentication_methods) do
    Enum.reduce_while(authentication_methods, nil, fn
      %{"type" => "OTP", "phone_number" => phone_number}, _acc ->
        {:halt, phone_number}

      _, acc ->
        {:cont, acc}
    end)
  end

  def normalize_person(
        %Person{
          first_name: first_name,
          last_name: last_name,
          second_name: second_name,
          birth_settlement: birth_settlement,
          documents: documents,
          addresses: addresses
        } = person
      ) do
    %{
      person
      | first_name: normalize_text(first_name),
        last_name: normalize_text(last_name),
        second_name: normalize_text(second_name),
        birth_settlement: normalize_birth_settlement(birth_settlement),
        documents: normalize_documents(documents),
        addresses: normalize_addresses(addresses)
    }
  end

  def normalize_birth_settlement(birth_settlement) when is_binary(birth_settlement) do
    r =
      Regex.compile!(
        "([сc][ \.,])|([сc]ело[\.,]*)|([сc]мт[\.,]*)|([сc]елище [мm][іi][сc]ького " <>
          "типу)|([сc]елище[\.,]*)|([мm][іi][сc][tт][оo][\.,]*)|([мm][\.,]*)",
        "ui"
      )

    normalize_text(Regex.replace(r, birth_settlement, ""))
  end

  def normalize_documents(documents) do
    Enum.map(documents, fn %PersonDocument{type: type, number: number} ->
      document =
        case type do
          "BIRTH_CERTIFICATE" ->
            normalize_birth_certificate_document(number)

          _ ->
            normalize_document_number(number)
        end

      %{type: type, document: document, number: document_number(document)}
    end)
  end

  def normalize_addresses(addresses) do
    Enum.map(addresses, fn %PersonAddress{type: type, settlement: settlement} ->
      %{type: type, settlement: settlement}
    end)
  end
end
