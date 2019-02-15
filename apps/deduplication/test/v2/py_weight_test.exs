defmodule Deduplication.V2.PyWeightTest do
  use Core.ModelCase, async: false

  alias Deduplication.V2.PyWeight

  test "correct weight for single data set" do
    final_weights = %{
      person_id: "0050e680-8ceb-472e-a151-93a863e7768e",
      candidate_id: "2ee5e195-9d42-47c6-a2a7-4fff85dcbd89",
      d_first_name_bin: 0,
      d_last_name_bin: 4,
      d_second_name_bin: 3,
      d_documents_bin: "0x<6",
      docs_same_number_bin: "0x4",
      birth_settlement_substr_bin: 1,
      d_tax_id_bin: 1,
      authentication_methods_flag_bin: 1,
      residence_settlement_flag_bin: 0,
      gender_flag_bin: 0,
      twins_flag_bin: 0
    }

    assert Float.round(0.40259353, 5) == PyWeight.weight(final_weights)
  end

  test "test on CSV dataset" do
    Path.join(__DIR__, "docs_issue_sample_test_result.csv")
    |> File.read!()
    |> String.split()
    |> Enum.drop(1)
    |> Task.async_stream(fn csv_str ->
      [
        id1,
        id2,
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
        predicted_target_1
      ] = String.split(csv_str, ",")

      final_weights = %{
        person_id: id1,
        candidate_id: id2,
        d_first_name_bin: parse_int(d_first_name_bin),
        d_last_name_bin: parse_int(d_last_name_bin),
        d_second_name_bin: parse_int(d_second_name_bin),
        d_documents_bin: d_documents_bin,
        docs_same_number_bin: docs_same_number_bin,
        birth_settlement_substr_bin: parse_int(birth_settlement_substr_bin),
        d_tax_id_bin: parse_int(d_tax_id_bin),
        authentication_methods_flag_bin: parse_int(authentication_methods_flag_bin),
        residence_settlement_flag_bin: parse_int(residence_settlement_flag_bin),
        gender_flag_bin: parse_int(gender_flag_bin),
        twins_flag_bin: parse_int(twins_flag_bin)
      }

      predicted_target_1 = parse_float(predicted_target_1) |> Float.round(5)
      weight = PyWeight.weight(final_weights)

      assert predicted_target_1 == weight
    end)
    |> Stream.run()
  end

  defp parse_int(str) when is_binary(str) do
    {res, ""} = Integer.parse(str)
    res
  end

  defp parse_float(str) when is_binary(str) do
    {res, ""} = Float.parse(str)
    res
  end
end
