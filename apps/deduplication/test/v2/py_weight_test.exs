defmodule Deduplication.V2.PyWeightTest do
  use Core.ModelCase, async: false

  alias Deduplication.V2.PyWeight
  # alias Deduplication.V2.DistanceModel

  test "weight close to 0" do
    final_weights = %{
      person_id: Ecto.UUID.generate(),
      candidate_id: Ecto.UUID.generate(),
      d_first_name_woe: 4.278408035,
      d_second_name_woe: 2.050493088,
      d_last_name_woe: 3.421035127,
      d_documents_woe: -2.12133861,
      docs_same_number_woe: -2.065190805,
      birth_settlement_substr_woe: 1.625216412,
      d_tax_id_woe: -0.217612736,
      residence_settlement_flag_woe: 2.312877566,
      registration_address_settlement_flag_woe: 2.456584084,
      authentication_methods_flag_woe: 1.242406002,
      gender_flag_woe: 2.886330559,
      twins_flag_woe: -0.159950822
    }

    assert Float.round(0.0025492741919554873, 5) == PyWeight.weight(final_weights)
  end

  test "weight close to 1" do
    final_weights = %{
      person_id: Ecto.UUID.generate(),
      candidate_id: Ecto.UUID.generate(),
      d_first_name_woe: -2.801009159,
      d_second_name_woe: -1.405398133,
      d_last_name_woe: -1.181889463,
      d_documents_woe: 1.957050787,
      docs_same_number_woe: -2.065190805,
      birth_settlement_substr_woe: -1.033368721,
      d_tax_id_woe: -0.217612736,
      residence_settlement_flag_woe: -0.906624219,
      registration_address_settlement_flag_woe: -0.937089181,
      authentication_methods_flag_woe: -0.962223178,
      gender_flag_woe: -0.43537168,
      twins_flag_woe: -0.159950822
    }

    assert Float.round(0.8795415436523658, 5) == PyWeight.weight(final_weights)
  end

  test "test on CSV dataset" do
    Path.join(__DIR__, "test_model_not_scaled_boosted.csv")
    |> File.read!()
    |> String.split()
    |> Enum.drop(1)
    |> Task.async_stream(fn csv_str ->
      [
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
        twins_flag_woe,
        predicted_target_1
      ] = String.split(csv_str, ",")

      final_weights = %{
        person_id: Ecto.UUID.generate(),
        candidate_id: Ecto.UUID.generate(),
        d_first_name_woe: parse_float(d_first_name_woe),
        d_second_name_woe: parse_float(d_second_name_woe),
        d_last_name_woe: parse_float(d_last_name_woe),
        d_documents_woe: parse_float(d_documents_woe),
        docs_same_number_woe: parse_float(docs_same_number_woe),
        birth_settlement_substr_woe: parse_float(birth_settlement_substr_woe),
        d_tax_id_woe: parse_float(d_tax_id_woe),
        residence_settlement_flag_woe: parse_float(residence_settlement_flag_woe),
        registration_address_settlement_flag_woe: parse_float(registration_address_settlement_flag_woe),
        authentication_methods_flag_woe: parse_float(authentication_methods_flag_woe),
        gender_flag_woe: parse_float(gender_flag_woe),
        twins_flag_woe: parse_float(twins_flag_woe)
      }

      predicted_target_1 = parse_float(predicted_target_1) |> Float.round(5)
      weight = PyWeight.weight(final_weights)

      assert predicted_target_1 == weight
    end)
    |> Stream.run()
  end

  defp parse_float(str) when is_binary(str) do
    {res, ""} = Float.parse(str)
    res
  end
end
