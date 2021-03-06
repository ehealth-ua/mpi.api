defmodule Deduplication.DistanceModel do
  @moduledoc false
  defstruct person_id: nil,
            candidate_id: nil,
            distance_first_name: nil,
            distance_last_name: nil,
            distance_second_name: nil,
            distance_documents: nil,
            docs_same_number: nil,
            document_number_length: nil,
            document_distinct: nil,
            birth_settlement_substr: nil,
            distance_tax_id: nil,
            residence_settlement_flag: nil,
            authentication_methods_flag: nil,
            gender_flag: nil,
            twins_flag: nil
end
