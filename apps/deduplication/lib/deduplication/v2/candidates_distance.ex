defmodule Deduplication.V2.CandidatesDistance do
  @moduledoc """
  Count Leveshtein weigth for candidate pairs
  """

  alias Core.Person
  alias Deduplication.V2.DistanceModel
  alias Simetric.Levenshtein

  @document_types ~w(
       PASSPORT
       BIRTH_CERTIFICATE
       NATIONAL_ID
       COMPLEMENTARY_PROTECTION_CERTIFICATE
       PERMANENT_RESIDENCE_PERMIT
       REFUGEE_CERTIFICATE
       TEMPORARY_CERTIFICATE
       TEMPORARY_PASSPORT
       )

  def finalize_weight(%DistanceModel{} = model) do
    %{
      person_id: model.person_id,
      candidate_id: model.candidate_id,
      d_first_name_bin: d_first_name_bin(model.distance_first_name),
      d_last_name_bin: d_last_name_bin(model.distance_last_name),
      d_second_name_bin: d_second_name_bin(model.distance_second_name),
      d_documents_bin: d_documents_bin(model.distance_documents, model.document_number_length),
      docs_same_number_bin: docs_same_number_bin(model.docs_same_number, model.document_distinct),
      birth_settlement_substr_bin: model.birth_settlement_substr,
      d_tax_id_bin: d_tax_id_bin(model.distance_tax_id),
      authentication_methods_flag_bin: model.authentication_methods_flag,
      residence_settlement_flag_bin: model.residence_settlement_flag,
      gender_flag_bin: model.gender_flag,
      twins_flag_bin: model.twins_flag
    }
  end

  def d_first_name_bin(distance_first_name) do
    cond do
      distance_first_name in 0..1 -> 0
      distance_first_name == 2 -> 2
      true -> 3
    end
  end

  def d_last_name_bin(distance_last_name) do
    cond do
      distance_last_name in 0..1 -> 1
      distance_last_name == 2 -> 2
      distance_last_name == 3 -> 3
      true -> 4
    end
  end

  def d_second_name_bin(distance_second_name) do
    cond do
      distance_second_name in 0..2 -> 1
      distance_second_name == nil -> 2
      distance_second_name in 3..6 -> 3
      true -> 4
    end
  end

  def d_documents_bin(distance_documents, document_number_length) do
    cond do
      (distance_documents == 0 or distance_documents == nil) and document_number_length == nil -> "0x1"
      distance_documents == 0 and document_number_length <= 4 -> "0x<4"
      distance_documents == 0 and document_number_length <= 6 -> "0x<6"
      distance_documents == 0 and document_number_length > 6 -> "0x>6"
      distance_documents == 1 and (document_number_length <= 6 or document_number_length == nil) -> "1x<6"
      distance_documents == 1 and document_number_length > 6 -> "1x>6"
      distance_documents <= 3 -> "2"
      true -> "3"
    end
  end

  def docs_same_number_bin(docs_same_number, document_distinct) when not is_nil(document_distinct) do
    cond do
      docs_same_number == 0 and document_distinct == 1 -> "0x1"
      docs_same_number == 0 and document_distinct == 2 -> "0x2"
      docs_same_number == 0 and document_distinct == 3 -> "0x3"
      docs_same_number == 0 and document_distinct > 3 -> "0x4"
      docs_same_number == 1 and document_distinct == 0 -> "1x0"
      docs_same_number == 1 and document_distinct <= 3 -> "1x2"
      docs_same_number == 1 and document_distinct >= 4 -> "1x3"
    end
  end

  def d_tax_id_bin(distance_tax_id) do
    cond do
      distance_tax_id == 0 -> 0
      distance_tax_id == nil -> 1
      distance_tax_id in 1..2 -> 2
      true -> 3
    end
  end

  def levenshtein_weight(
        %Person{
          documents: person_documents,
          addresses: person_addresses,
          authentication_methods: person_phones
        } = person,
        %Person{
          documents: candidate_documents,
          addresses: candidate_addresses,
          authentication_methods: candidate_phones
        } = candidate
      ) do
    %{} = document_levenshtein = match_document_levenshtein(person_documents, candidate_documents)

    {document_number_length, document_distinct} = compare_document_numbers(person_documents, candidate_documents)

    %DistanceModel{
      person_id: person.id,
      candidate_id: candidate.id,
      distance_first_name: levenshtein(person.first_name, candidate.first_name),
      distance_last_name: levenshtein(person.last_name, candidate.last_name),
      distance_second_name: levenshtein(person.second_name, candidate.second_name),
      distance_documents: document_levenshtein[:levenshtein],
      docs_same_number: document_levenshtein[:same_number],
      document_number_length: document_number_length,
      document_distinct: document_distinct,
      birth_settlement_substr: birth_settlement_substr(person.birth_settlement, candidate.birth_settlement),
      distance_tax_id: levenshtein(person.tax_id, candidate.tax_id),
      residence_settlement_flag: equal_residence_addresses(person_addresses, candidate_addresses),
      authentication_methods_flag: equal_auth_phones(person_phones, candidate_phones),
      gender_flag: exactly_equals(person.gender, candidate.gender),
      twins_flag: twins_flag(person, candidate)
    }
  end

  defp birth_settlement_substr(person_birth_settlement, candidate_birth_settlement) do
    if position(person_birth_settlement, candidate_birth_settlement) > 0, do: 0, else: 1
  end

  def twins_flag(
        %Person{documents: person_documents} = person,
        %Person{documents: candidate_documents} = candidate
      ) do
    twins = documents_twins_flag(person_documents, candidate_documents)

    if levenshtein(person.last_name, candidate.last_name) < 3 and
         person.first_name != candidate.first_name and person.birth_date == candidate.birth_date and
         twins == 1 do
      1
    else
      0
    end
  end

  def levenshtein(dest, src) when is_binary(dest) and is_binary(src),
    do: Levenshtein.compare(dest, src)

  def levenshtein(_, _), do: nil

  def equal_auth_phones(person_phones, candidate_phones) do
    person_phone = get_element_by_type("OTP", "phone_number", person_phones)
    candidate_phone = get_element_by_type("OTP", "phone_number", candidate_phones)

    exactly_equals(person_phone, candidate_phone)
  end

  def equal_residence_addresses(person_addresses, candidate_addresses) do
    person_address = get_element_by_type("RESIDENCE", :settlement, person_addresses)
    candidate_address = get_element_by_type("RESIDENCE", :settlement, candidate_addresses)

    exactly_equals(person_address, candidate_address)
  end

  def documents_twins_flag(person_documents, candidate_documents) do
    @document_types
    |> Enum.reduce_while(0, fn type, acc ->
      person_number = get_element_by_type(type, :number, person_documents)
      candidate_number = get_element_by_type(type, :number, candidate_documents)

      if document_number_abs(person_number, candidate_number) in 1..2 do
        {:halt, 1}
      else
        {:cont, acc}
      end
    end)
  end

  def match_document_levenshtein(person_documents, candidate_documents)
      when is_list(person_documents) and is_list(candidate_documents) do
    Enum.reduce_while(person_documents, %{levenshtein: nil, same_number: 1}, fn pd, result ->
      if %{levenshtein: 0, same_number: 0} == result do
        {:halt, result}
      else
        result =
          Enum.reduce_while(candidate_documents, result, fn cd, acc ->
            if %{levenshtein: 0, same_number: 0} == acc do
              {:halt, acc}
            else
              levenshtein = check_documents_levenshtein(Map.get(pd, :document), Map.get(cd, :document), acc)

              same_number = check_documents_same_number(Map.get(pd, :number), Map.get(cd, :number), acc)

              {:cont, %{levenshtein: levenshtein, same_number: same_number}}
            end
          end)

        {:cont, result}
      end
    end)
  end

  def check_documents_levenshtein(pd_document, cd_document, %{levenshtein: levenshtein})
      when is_nil(pd_document) or is_nil(cd_document),
      do: levenshtein

  def check_documents_levenshtein(pd_document, cd_document, %{levenshtein: nil}),
    do: Levenshtein.compare(pd_document, cd_document)

  def check_documents_levenshtein(pd_document, cd_document, %{levenshtein: current_levenshtein}) do
    levenshtein = Levenshtein.compare(pd_document, cd_document)

    if levenshtein < current_levenshtein, do: levenshtein, else: current_levenshtein
  end

  def check_documents_same_number(_, _, %{same_number: 0}), do: 0

  def check_documents_same_number(pd_number, cd_number, _),
    do: exactly_equals(pd_number, cd_number)

  def position(string1, string2) when is_binary(string1) and is_binary(string2) do
    length1 = String.length(string1)
    length2 = String.length(string2)

    {subject, pattern} =
      if length1 > length2 do
        {string1, string2}
      else
        {string2, string1}
      end

    case String.split(subject, pattern) do
      [_subject] -> 0
      [w | _] -> String.length(w) + 1
    end
  end

  def position(_, _), do: 0

  def get_element_by_type(type, key, elements) do
    Enum.reduce_while(elements, nil, fn
      %{type: ^type} = element, _acc ->
        {:halt, element[key]}

      %{"type" => ^type} = element, _acc ->
        {:halt, element[key]}

      _, acc ->
        {:cont, acc}
    end)
  end

  def exactly_equals(v, v) when not is_nil(v), do: 0
  def exactly_equals(_, _), do: 1

  def document_number_abs(nil, _), do: 0
  def document_number_abs(_, nil), do: 0
  def document_number_abs("", _), do: 0
  def document_number_abs(_, ""), do: 0

  def document_number_abs(n1, n2) do
    abs(String.to_integer(n1) - String.to_integer(n2))
  end

  def compare_document_numbers(person_documents, candidate_documents) do
    all_documents = []
    all_documents = all_documents ++ person_documents || []
    all_documents = all_documents ++ candidate_documents || []

    Enum.reduce(all_documents, {nil, 0}, fn doc, {shortest_number, shortest_distinct_digits} ->
      case Map.get(doc, :number) do
        nil -> {shortest_number, shortest_distinct_digits}
        number -> do_compare_document_numbers(number, shortest_number, shortest_distinct_digits)
      end
    end)
  end

  defp do_compare_document_numbers(doc_number, shortest_number, shortest_distinct_digits) do
    digits = String.codepoints(doc_number)
    nums_length = if digits == [], do: nil, else: length(digits)
    distinct_digs = length(Enum.uniq(digits))

    shortest_number = if nums_length < shortest_number, do: nums_length, else: shortest_number

    shortest_distinct_digits =
      if shortest_distinct_digits == 0 or distinct_digs < shortest_distinct_digits,
        do: distinct_digs,
        else: shortest_distinct_digits

    {shortest_number, shortest_distinct_digits}
  end
end
