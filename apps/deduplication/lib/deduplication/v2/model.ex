defmodule Deduplication.V2.Model do
  @moduledoc """
  Quering persons and prepare data
  """
  use Confex, otp_app: :deduplication
  import Ecto.Query

  alias Core.Person
  alias Core.PersonAddress
  alias Core.PersonDocument
  alias Core.Repo
  alias Core.VerifiedTs
  alias Core.VerifyingIds

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

  def set_current_verified_ts(updated_at) do
    query =
      from(p in VerifiedTs,
        where: p.id == ^0,
        update: [set: [inserted_at: ^DateTime.utc_now(), updated_at: ^updated_at]]
      )

    {row_updated, _} = Repo.update_all(query, [])
    true = row_updated in [0, 1]
  end

  def lock_persons_on_verify([]), do: []

  def lock_persons_on_verify(persons) do
    person_ids = Enum.map(persons, &%{id: &1.id})

    max_updated_at =
      persons
      |> Enum.map(& &1.updated_at)
      |> Enum.sort(fn x, y ->
        case DateTime.compare(x, y) do
          :gt -> true
          _ -> false
        end
      end)
      |> hd

    {_, nil} = Repo.insert_all(VerifyingIds, person_ids)
    set_current_verified_ts(max_updated_at)
    persons
  end

  def unlock_person_after_verify(person_id) do
    {_, nil} = Repo.delete_all(from(p in VerifyingIds, where: p.id == ^person_id))
  end

  def no_locked_pesons? do
    VerifyingIds
    |> limit(^1)
    |> Repo.all()
    |> Enum.empty?()
  end

  def get_locked_unverified_persons(limit, offset) do
    Person
    |> preload([:documents, :person_addresses])
    |> join(:inner, [p], v in VerifyingIds, v.id == p.id)
    |> order_by([p, v], p.id)
    |> limit(^limit)
    |> offset(^offset)
    |> Repo.all()
  end

  def get_unverified_persons(limit) do
    Person
    |> preload([:documents, :person_addresses])
    |> join(:left, [p], v in VerifyingIds, v.id == p.id)
    |> where(
      [p, v],
      is_nil(v.id) and
        fragment(
          "? > (select updated_at from verified_ts)",
          p.updated_at
        )
    )
    |> order_by([p], p.updated_at)
    |> limit(^limit)
    |> Repo.all()
    |> lock_persons_on_verify()
  end

  def settlement_name_query(query, :first_name, first_name) do
    where(query, [p, a], p.first_name == ^first_name)
  end

  def settlement_name_query(query, :last_name, last_name) do
    where(query, [p, a], p.last_name == ^last_name)
  end

  @doc """
  Makes union subqueries because plan is not optimal for one query
  """
  def get_candidates(%Person{} = person) do
    documents_numbers =
      person.documents
      |> Enum.map(&document_number(&1.number))
      |> Enum.uniq()

    auth_phone_number = person_auth_phone(person.authentication_methods)

    settlement_ids =
      person.person_addresses
      |> Enum.map(fn address ->
        {:ok, id} = Ecto.UUID.dump(address.settlement_id)
        id
      end)
      |> Enum.uniq()

    retrieve_candidates(person, documents_numbers, auth_phone_number, settlement_ids)
  end

  def retrieve_candidates(person, documents_numbers, auth_phone_number, settlement_ids) do
    limit = config()[:candidates_batch_size]

    retrieve_candidates(
      [],
      limit,
      0,
      person,
      documents_numbers,
      auth_phone_number,
      settlement_ids
    )
  end

  def retrieve_candidates(
        accum,
        limit,
        offset,
        person,
        documents_numbers,
        auth_phone_number,
        settlement_ids
      ) do
    documents_numbers_only =
      documents_numbers
      |> Enum.filter(fn
        "" -> false
        _ -> true
      end)
      |> MapSet.new()
      |> MapSet.to_list()

    # add false if null - subquery parametrs can not be removed
    current_candidates =
      Person
      |> preload([p, ca], [:documents, :person_addresses])
      |> join(
        # allow right join, to avoid long nested loop
        :right,
        [p],
        ca in fragment(
          "
          (SELECT DISTINCT person_id id
             FROM person_documents WHERE (regexp_replace(number, '[^[:digit:]]', '', 'g') = ANY(?)))
          UNION
          (SELECT id FROM persons WHERE tax_id = ? and tax_id IS NOT NULL)
          UNION
          (SELECT id FROM persons WHERE authentication_methods @> ?)
          UNION
          (SELECT DISTINCT person_id id FROM person_addresses WHERE
             person_first_name = ? and settlement_id = ANY(?))
          UNION
          (SELECT DISTINCT person_id id FROM person_addresses WHERE
             person_last_name = ? and settlement_id = ANY(?))
          ",
          ^documents_numbers_only,
          ^person.tax_id,
          ^[%{"phone_number" => auth_phone_number, "type" => "OTP"}],
          ^person.first_name,
          ^settlement_ids,
          ^person.last_name,
          ^settlement_ids
        ),
        ca.id == p.id
      )
      # recheck id is not null after right join
      |> where(
        [p, ca],
        p.id != ^person.id and p.updated_at < ^person.updated_at and not is_nil(p.id)
      )
      |> order_by([p, ca], p.updated_at)
      |> limit(^limit)
      |> offset(^offset)
      |> Repo.all()

    candidates = current_candidates ++ accum

    case current_candidates do
      [] ->
        candidates

      _ ->
        retrieve_candidates(
          candidates,
          limit,
          offset + limit,
          person,
          documents_numbers,
          auth_phone_number,
          settlement_ids
        )
    end
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
          tax_id: tax_id,
          documents: documents,
          person_addresses: addresses
        } = person
      ) do
    normalized_documents = normalize_documents(documents)

    %{
      person
      | first_name: normalize_text(first_name),
        last_name: normalize_text(last_name),
        second_name: normalize_text(second_name),
        birth_settlement: normalize_birth_settlement(birth_settlement),
        tax_id: normalize_tax_id(tax_id, normalized_documents),
        documents: normalized_documents,
        person_addresses: normalize_addresses(addresses)
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

  def normalize_tax_id(tax_id, _) when not is_nil(tax_id), do: tax_id

  def normalize_tax_id(nil, documents) do
    Enum.reduce_while(documents, nil, fn
      %{number: nil}, _ ->
        {:cont, nil}

      %{number: number}, _ ->
        if String.length(number) == 10,
          do: {:halt, number},
          else: {:cont, nil}
    end)
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
