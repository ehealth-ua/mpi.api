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
      d_documents_bin: d_documents_bin(model.distance_documents),
      docs_same_number_bin: model.docs_same_number,
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
      distance_first_name == 0 -> 0
      distance_first_name == 1 -> 1
      distance_first_name == 2 -> 2
      true -> 3
    end
  end

  def d_last_name_bin(distance_last_name) do
    cond do
      distance_last_name in 0..1 -> 1
      distance_last_name == 2 -> 2
      true -> 3
    end
  end

  def d_second_name_bin(distance_second_name) do
    cond do
      distance_second_name in 0..2 -> 1
      is_nil(distance_second_name) -> 2
      distance_second_name in 3..4 -> 3
      true -> 4
    end
  end

  def d_documents_bin(distance_documents) do
    cond do
      distance_documents == 0 -> 1
      distance_documents in 1..3 -> 2
      distance_documents in 4..6 or is_nil(distance_documents) -> 3
      true -> 4
    end
  end

  def d_tax_id_bin(distance_tax_id) do
    cond do
      distance_tax_id == 0 -> 0
      is_nil(distance_tax_id) -> 1
      true -> 2
    end
  end

  def levenshtein_weight(
        %Person{
          documents: person_documents,
          person_addresses: person_addresses,
          authentication_methods: person_phones
        } = person,
        %Person{
          documents: candidate_documents,
          person_addresses: candidate_addresses,
          authentication_methods: candidate_phones
        } = candidate
      ) do
    %{} = document_levenshtein = match_document_levenshtein(person_documents, candidate_documents)

    %DistanceModel{
      person_id: person.id,
      candidate_id: candidate.id,
      distance_first_name: levenshtein(person.first_name, candidate.first_name),
      distance_last_name: levenshtein(person.last_name, candidate.last_name),
      distance_second_name: levenshtein(person.second_name, candidate.second_name),
      distance_documents: document_levenshtein[:levenshtein],
      docs_same_number: document_levenshtein[:same_number],
      birth_settlement_substr:
        birth_settlement_substr(person.birth_settlement, candidate.birth_settlement),
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
              levenshtein =
                check_documents_levenshtein(Map.get(pd, :document), Map.get(cd, :document), acc)

              same_number =
                check_documents_same_number(Map.get(pd, :number), Map.get(cd, :number), acc)

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
end
