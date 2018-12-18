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
      d_first_name_woe: d_first_name_woe(model.distance_first_name),
      d_last_name_woe: d_last_name_woe(model.distance_last_name),
      d_second_name_woe: d_second_name_woe(model.distance_second_name),
      d_documents_woe: d_documents_woe(model.distance_documents),
      docs_same_number_woe: docs_same_number_woe(model.docs_same_number),
      birth_settlement_substr_woe: birth_settlement_substr_woe(model.birth_settlement_substr),
      d_tax_id_woe: d_tax_id_woe(model.distance_tax_id),
      authentication_methods_flag_woe: authentication_methods_flag_woe(model.authentication_methods_flag),
      residence_settlement_flag_woe: residence_settlement_flag_woe(model.residence_settlement_flag),
      registration_address_settlement_flag_woe:
        registration_address_settlement_flag_woe(model.registration_address_settlement_flag),
      gender_flag_woe: gender_flag_woe(model.gender_flag),
      twins_flag_woe: twins_flag_woe(model.twins_flag)
    }
  end

  # d_first_name = 0 -> d_first_name_bin = 0
  # d_first_name = 1 -> d_first_name_bin = 1
  # d_first_name = 2 -> d_first_name_bin = 2
  # else -> d_first_name_bin =3
  def d_first_name_woe(distance_first_name) do
    cond do
      distance_first_name == 0 -> -2.801009159
      distance_first_name == 1 -> -1.379763317
      distance_first_name == 2 -> 0.896797543
      true -> 4.278408035
    end
  end

  # d_last_name between 0 and 1 -> d_last_name_bin = 1
  # d_last_name = 2 -> d_last_name_bin = 2
  # else -> d_last_name_bin = 3
  def d_last_name_woe(distance_last_name) do
    cond do
      distance_last_name in 0..1 -> -1.181889463
      distance_last_name == 2 -> -0.716750603
      true -> 3.421035127
    end
  end

  # d_second_name between 0 and 2 -> d_second_name_bin = 1
  # d_second_name is null -> d_second_name_bin = 2
  # d_second_name between 3 and 4 -> d_second_name_bin = 3
  # else -> d_second_name_bin = 4
  def d_second_name_woe(distance_second_name) do
    cond do
      distance_second_name in 0..2 -> -1.405398133
      is_nil(distance_second_name) -> -0.988391454
      distance_second_name in 3..4 -> 2.050493088
      true -> 2.589141853
    end
  end

  # d_documents = 0 -> d_documents_bin = 1
  # d_documents between 1 and 3 -> d_documents_bin = 2
  # d_documents between 4 and 6 or d_documents is null -> d_documents_bin = 3
  # else -> d_documents_bin = 4
  def d_documents_woe(distance_documents) do
    cond do
      distance_documents == 0 -> -2.12133861
      distance_documents in 1..3 -> 0.907611604
      distance_documents in 4..6 or is_nil(distance_documents) -> 1.957050787
      true -> 2.559220981
    end
  end

  def docs_same_number_woe(docs_same_number) do
    if docs_same_number == 0,
      do: -2.065190805,
      else: 1.485675379
  end

  def birth_settlement_substr_woe(birth_settlement_substr) do
    if birth_settlement_substr == 0,
      do: -1.033368721,
      else: 1.625216412
  end

  # d_tax_id = 0 -> d_tax_id_bin = 0
  # d_tax_id is null -> d_tax_id_bin = 1
  # else d_tax_id_bin = 2
  def d_tax_id_woe(distance_tax_id) do
    cond do
      distance_tax_id == 0 -> -2.714837812
      is_nil(distance_tax_id) -> -0.217612736
      true -> 2.305107806
    end
  end

  def authentication_methods_flag_woe(authentication_methods_flag) do
    if authentication_methods_flag == 0,
      do: -0.962223178,
      else: 1.242406002
  end

  def residence_settlement_flag_woe(residence_settlement_flag) do
    if residence_settlement_flag == 0,
      do: -0.906624219,
      else: 2.312877566
  end

  def registration_address_settlement_flag_woe(registration_address_settlement_flag) do
    if registration_address_settlement_flag == 0,
      do: -0.937089181,
      else: 2.456584084
  end

  def gender_flag_woe(gender_flag) do
    if gender_flag == 0,
      do: -0.43537168,
      else: 2.886330559
  end

  def twins_flag_woe(twins_flag) do
    if twins_flag == 0,
      do: -0.159950822,
      else: 7.817262167
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
    %{} = addresses = equal_addresses(person_addresses, candidate_addresses)

    %DistanceModel{
      person_id: person.id,
      candidate_id: candidate.id,
      distance_first_name: levenshtein(person.first_name, candidate.first_name),
      distance_last_name: levenshtein(person.last_name, candidate.last_name),
      distance_second_name: levenshtein(person.second_name, candidate.second_name),
      distance_documents: document_levenshtein[:levenshtein],
      docs_same_number: document_levenshtein[:same_number],
      birth_settlement_substr: birth_settlement_substr(person.birth_settlement, candidate.birth_settlement),
      distance_tax_id: levenshtein(person.tax_id, candidate.tax_id),
      residence_settlement_flag: addresses["REGISTRATION"],
      registration_address_settlement_flag: addresses["REGISTRATION"],
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

    if levenshtein(person.last_name, candidate.last_name) < 3 and person.first_name != candidate.first_name and
         person.birth_date == candidate.birth_date and twins == 1 do
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

  def equal_addresses(person_addresses, candidate_addresses) do
    ~w(REGISTRATION RESIDENCE)
    |> Enum.reduce(%{}, fn type, acc ->
      person_address = get_element_by_type(type, :settlement, person_addresses)
      candidate_address = get_element_by_type(type, :settlement, candidate_addresses)
      Map.put(acc, type, exactly_equals(person_address, candidate_address))
    end)
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
    match_person_documents_levenshtein(person_documents, candidate_documents, %{})
  end

  defp match_person_documents_levenshtein(_, _, %{levenshtein: 0, same_number: 0} = result), do: result

  defp match_person_documents_levenshtein([], _, result), do: result

  defp match_person_documents_levenshtein([pd_h | pd_t], candidate_documents, result) do
    case Map.get(pd_h, :document) do
      nil ->
        match_person_documents_levenshtein(pd_t, candidate_documents, result)

      person_document ->
        upd_result =
          match_person_document_candidate_document_levenshtein(pd_h, person_document, candidate_documents, result)

        match_person_documents_levenshtein(pd_t, candidate_documents, upd_result)
    end
  end

  defp match_person_document_candidate_document_levenshtein(_, _, _, %{levenshtein: 0, same_number: 0} = result),
    do: result

  defp match_person_document_candidate_document_levenshtein(_, _, [], result), do: result

  defp match_person_document_candidate_document_levenshtein(pd, person_document, [cd_h | cd_t], result) do
    case Map.get(cd_h, :document) do
      nil ->
        match_person_document_candidate_document_levenshtein(pd, person_document, cd_t, result)

      candidate_document ->
        levenshtein = Levenshtein.compare(person_document, candidate_document)

        upd_result =
          case Map.get(result, :levenshtein) do
            nil -> Map.put(result, :levenshtein, levenshtein)
            acc_levenshtein when acc_levenshtein > levenshtein -> Map.put(result, :levenshtein, levenshtein)
            acc_levenshtein when acc_levenshtein <= levenshtein -> result
          end

        upd_result =
          if Map.get(upd_result, :same_number) == 0 do
            upd_result
          else
            same_number = exactly_equals(Map.get(pd, :number), Map.get(cd_h, :number))
            Map.put(upd_result, :same_number, same_number)
          end

        match_person_document_candidate_document_levenshtein(pd, person_document, cd_t, upd_result)
    end
  end

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
