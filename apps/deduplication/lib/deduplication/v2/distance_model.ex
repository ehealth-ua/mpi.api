defmodule Deduplication.V2.DistanceModel do
  @moduledoc false
  defstruct person_id: nil,
            candidate_id: nil,
            distance_first_name: nil,
            distance_last_name: nil,
            distance_second_name: nil,
            distance_documents: nil,
            docs_same_number: nil,
            birth_settlement_substr: nil,
            distance_tax_id: nil,
            residence_settlement_flag: nil,
            registration_address_settlement_flag: nil,
            authentication_methods_flag: nil,
            gender_flag: nil,
            twins_flag: nil
end
