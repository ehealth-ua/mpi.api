defmodule Deduplication.V2.CandidatesDistanceTest do
  @moduledoc false
  use Core.ModelCase, async: false
  import Core.Factory

  alias Deduplication.V2.CandidatesDistance
  alias Deduplication.V2.DistanceModel
  alias Ecto.UUID

  describe "counting functions" do
    test "equal works" do
      assert 32 == CandidatesDistance.document_number_abs("1", "33")
      assert 0 == CandidatesDistance.document_number_abs("1", nil)
      assert 0 == CandidatesDistance.document_number_abs(nil, "1")
    end

    test "exactly_equals works" do
      assert 1 == CandidatesDistance.exactly_equals(nil, 1)
      assert 1 == CandidatesDistance.exactly_equals(1, nil)
      assert 0 == CandidatesDistance.exactly_equals("d", "d")
      assert 1 == CandidatesDistance.exactly_equals("2", "d")
    end

    test "get_element_by_type works" do
      elements = [%{a: 1}, %{}, %{:type => "OTP", "phone" => 1}]
      assert 1 == CandidatesDistance.get_element_by_type("OTP", "phone", elements)

      elements = [%{}, %{s: 1}, %{"type" => "OTP", "phone" => 2}, %{"f" => 1}]
      assert 2 == CandidatesDistance.get_element_by_type("OTP", "phone", elements)

      elements = [%{}, %{type: "CERT"}, %{type: "PASSPORT", document: "EH345678"}, %{"f" => 1}]
      assert "EH345678" == CandidatesDistance.get_element_by_type("PASSPORT", :document, elements)
    end

    test "position works" do
      assert 4 == CandidatesDistance.position("1234", "12412344")
      assert 4 == CandidatesDistance.position("1241234", "1234")
      assert 0 == CandidatesDistance.position("12412344", "67")
      assert 0 == CandidatesDistance.position("12412344", nil)
      assert 0 == CandidatesDistance.position(nil, "67")
      assert 0 == CandidatesDistance.position(nil, nil)
    end

    test "match_document_levenshtein no match works" do
      assert %{} = CandidatesDistance.match_document_levenshtein([], [])

      assert %{} ==
               CandidatesDistance.match_document_levenshtein(
                 [%{type: "TEMPORARY_CERTIFICATE"}, %{type: "PASSPORT"}],
                 []
               )

      assert %{} ==
               CandidatesDistance.match_document_levenshtein(
                 [%{type: "TEMPORARY_CERTIFICATE"}, %{type: "PASSPORT"}],
                 [%{type: "REFUGEE_CERTIFICATE"}, %{type: "NATIONAL_ID"}]
               )
    end

    test "match_document_levenshtein 1 match works" do
      assert %{levenshtein: 8, same_number: 1} ==
               CandidatesDistance.match_document_levenshtein(
                 [
                   %{type: "REFUGEE_CERTIFICATE", number: "123456789", document: "a1b2c3b4"},
                   %{type: "PASSPORT"}
                 ],
                 [
                   %{type: "REFUGEE_CERTIFICATE", number: "9999999", document: "qazwsx123"},
                   %{type: "NATIONAL_ID"}
                 ]
               )

      assert %{levenshtein: 0, same_number: 0} ==
               CandidatesDistance.match_document_levenshtein(
                 [
                   %{type: "REFUGEE_CERTIFICATE", number: "123456789", document: "a1b2c3b4"},
                   %{type: "PASSPORT"}
                 ],
                 [
                   %{type: "REFUGEE_CERTIFICATE", number: "123456789", document: "a1b2c3b4"},
                   %{type: "NATIONAL_ID"}
                 ]
               )

      assert %{levenshtein: 3, same_number: 0} ==
               CandidatesDistance.match_document_levenshtein(
                 [
                   %{type: "REFUGEE_CERTIFICATE", number: "123456789", document: "z1x2c3v4"},
                   %{type: "PASSPORT"}
                 ],
                 [
                   %{type: "TEMPORARY_CERTIFICATE", number: "123456789", document: "a1b2c3b4"},
                   %{type: "NATIONAL_ID"}
                 ]
               )
    end

    test "match_document_levenshtein 1 match works with different document types" do
      assert %{levenshtein: 8, same_number: 1} ==
               CandidatesDistance.match_document_levenshtein(
                 [
                   %{type: "PASSPORT", number: "123456789", document: "a1b2c3b4"}
                 ],
                 [
                   %{type: "NATIONAL_ID", number: "9999999", document: "qazwsx123"}
                 ]
               )

      assert %{levenshtein: 3, same_number: 0} ==
               CandidatesDistance.match_document_levenshtein(
                 [
                   %{type: "REFUGEE_CERTIFICATE", number: "123456789", document: "z1x2c3v4"}
                 ],
                 [
                   %{type: "TEMPORARY_CERTIFICATE", number: "123456789", document: "a1b2c3b4"}
                 ]
               )
    end

    test "match_document_levenshtein few matches works" do
      assert %{levenshtein: 1, same_number: 0} ==
               CandidatesDistance.match_document_levenshtein(
                 [
                   %{type: "PASSPORT", document: "абвг12345", number: "12345"},
                   %{
                     type: "REFUGEE_CERTIFICATE",
                     number: "123456789",
                     document: "12d3f45hh6g78k9"
                   }
                 ],
                 [
                   %{type: "REFUGEE_CERTIFICATE", number: "123456789", document: "tttttt"},
                   %{type: "PASSPORT", document: "абвг1д2345", number: "12345"}
                 ]
               )
    end

    test "match_document_levenshtein few matches works with different document types" do
      assert %{levenshtein: 3, same_number: 0} ==
               CandidatesDistance.match_document_levenshtein(
                 [
                   %{type: "PASSPORT", number: "123456789", document: "a1b2c3b4"},
                   %{type: "REFUGEE_CERTIFICATE", number: "123456789", document: "z1x2c3v4"}
                 ],
                 [
                   %{type: "NATIONAL_ID", number: "9999999", document: "qazwsx123"},
                   %{type: "TEMPORARY_CERTIFICATE", number: "123456789", document: "s1f2e3v4"}
                 ]
               )
    end

    test "documents_twins_flag works" do
      assert 1 ==
               CandidatesDistance.documents_twins_flag(
                 [
                   %{type: "NATIONAL_ID", document: "19930825-00000", number: "000000001"},
                   %{
                     type: "PERMANENT_RESIDENCE_PERMIT",
                     number: "123456789",
                     document: "12d3f45hh6g78k9"
                   }
                 ],
                 [
                   %{
                     type: "PERMANENT_RESIDENCE_PERMIT",
                     number: "123456788",
                     document: "12d3f45hh6g78k9"
                   },
                   %{type: "PASSPORT", document: "абвг1д2345", number: "12345"},
                   %{
                     type: "TEMPORARY_PASSPORT",
                     number: "8899123",
                     document: "88w99r12f3"
                   },
                   %{type: "BIRTH_CERTIFICATE", number: "01001", document: "fr0100f1"}
                 ]
               )

      assert 0 ==
               CandidatesDistance.documents_twins_flag(
                 [
                   %{type: "NATIONAL_ID", document: "19930825-00000", number: "000000001"},
                   %{
                     type: "PERMANENT_RESIDENCE_PERMIT",
                     number: "123456789",
                     document: "12d3f45hh6g78k9"
                   }
                 ],
                 [
                   %{
                     type: "PERMANENT_RESIDENCE_PERMIT",
                     number: "123456789",
                     document: "12d3f45hk6g78f9"
                   }
                 ]
               )
    end

    test "equal_addresses address not equal works" do
      assert %{"RESIDENCE" => 1, "REGISTRATION" => 1} ==
               CandidatesDistance.equal_addresses([], [])

      assert %{"RESIDENCE" => 1, "REGISTRATION" => 1} ==
               CandidatesDistance.equal_addresses(
                 [%{"type" => "RESIDENCE", "settlement" => "1234"}],
                 [%{"type" => "REGISTRATION", "settlement" => "4567"}]
               )

      assert %{"RESIDENCE" => 1, "REGISTRATION" => 1} ==
               CandidatesDistance.equal_addresses(
                 [%{"type" => "RESIDENCE", "settlement" => "1234"}],
                 [%{"type" => "RESIDENCE", "settlement" => "4567"}]
               )

      assert %{"RESIDENCE" => 1, "REGISTRATION" => 1} ==
               CandidatesDistance.equal_addresses(
                 [%{"type" => "RESIDENCE"}],
                 [%{"type" => "RESIDENCE"}]
               )
    end

    test "equal_addresses address equal works" do
      assert %{"RESIDENCE" => 0, "REGISTRATION" => 1} ==
               CandidatesDistance.equal_addresses(
                 [%{type: "RESIDENCE", settlement: "4567"}],
                 [%{type: "RESIDENCE", settlement: "4567"}]
               )

      assert %{"RESIDENCE" => 0, "REGISTRATION" => 0} ==
               CandidatesDistance.equal_addresses(
                 [
                   %{type: "REGISTRATION", settlement: "0123"},
                   %{type: "RESIDENCE", settlement: "4567"}
                 ],
                 [
                   %{type: "RESIDENCE", settlement: "4567"},
                   %{type: "REGISTRATION", settlement: "0123"}
                 ]
               )
    end

    test "equal_auth_phones no match works" do
      assert 1 == CandidatesDistance.equal_auth_phones([], [])

      assert 1 ==
               CandidatesDistance.equal_auth_phones([%{"type" => "OTP", "phone_number" => nil}], [
                 %{"phone_number" => "111", "type" => "OTP"}
               ])

      assert 1 ==
               CandidatesDistance.equal_auth_phones(
                 [%{"type" => "OTP", "phone_number" => "111"}],
                 [
                   %{"phone_number" => "111", "type" => "AUTH"}
                 ]
               )
    end

    test "equal_auth_phones  match works" do
      assert 0 ==
               CandidatesDistance.equal_auth_phones(
                 [%{"type" => "OTP", "phone_number" => "123"}],
                 [
                   %{"phone_number" => "123", "type" => "OTP"},
                   %{"phone_number" => "123", "type" => "AUTH"}
                 ]
               )
    end

    test "levenshtein works" do
      assert nil == CandidatesDistance.levenshtein(nil, "кіт")
      assert 1 == CandidatesDistance.levenshtein("кіт", "кит")
      assert 0 == CandidatesDistance.levenshtein("кіт", "кіт")
      assert 4 == CandidatesDistance.levenshtein("паляниця", "рушниця")
    end

    test "twins_flag for twins works" do
      brother =
        build(:person,
          first_name: "Іван",
          last_name: "Іванів",
          birth_date: ~D[1996-12-12],
          documents: [%{type: "PASSPORT", number: "7423"}]
        )

      sister =
        build(:person,
          first_name: "Іванна",
          last_name: "Іванова",
          birth_date: ~D[1996-12-12],
          documents: [%{type: "PASSPORT", number: "7422"}]
        )

      assert 1 == CandidatesDistance.twins_flag(sister, brother)
    end

    test "twins_flag for clones works" do
      person =
        build(:person,
          first_name: "Іван",
          last_name: "Іванів",
          birth_date: ~D[1996-12-12],
          documents: [%{type: "PASSPORT", number: "7423"}]
        )

      clone =
        build(:person,
          first_name: "Іванна",
          last_name: "Іванова",
          birth_date: ~D[1996-12-12],
          documents: [%{type: "PASSPORT", number: "7423"}]
        )

      assert 0 == CandidatesDistance.twins_flag(person, clone)
    end

    test "twins_flag for similar persons works" do
      person =
        build(:person,
          first_name: "Іван",
          last_name: "Іванів",
          birth_date: ~D[1996-12-12],
          documents: [%{type: "PASSPORT", number: "7423"}]
        )

      clone =
        build(:person,
          first_name: "Іванна",
          last_name: "Іванова",
          birth_date: ~D[1996-12-12],
          documents: [%{type: "BIRTH_CERTIFICATE", number: "7423"}]
        )

      assert 0 == CandidatesDistance.twins_flag(person, clone)
    end

    test "levenshtein_weight for similar persons works" do
      person =
        build(:person,
          id: UUID.generate(),
          gender: "male",
          tax_id: "1123456789",
          first_name: "Іван",
          last_name: "Іванів",
          second_name: "Петрович",
          birth_date: ~D[1996-12-12],
          birth_settlement: "смт. Рокита",
          documents: [%{type: "PASSPORT", document: "упп7423", number: "7423"}],
          authentication_methods: [%{"phone_number" => "123", "type" => "OTP"}],
          addresses: [
            %{type: "REGISTRATION", settlement: "0123"},
            %{type: "RESIDENCE", settlement: "4567"}
          ]
        )

      clone =
        build(:person,
          id: UUID.generate(),
          gender: "male",
          tax_id: "0123456789",
          first_name: "Іванн",
          last_name: "Іванова",
          second_name: "Петрович",
          birth_date: ~D[1996-12-12],
          birth_settlement: "Рокита",
          documents: [%{type: "PASSPORT", document: "пп7423", number: "7423"}],
          authentication_methods: [%{"phone_number" => "123", "type" => "OTP"}],
          addresses: [
            %{type: "REGISTRATION", settlement: "0123"},
            %{type: "RESIDENCE", settlement: "4567"}
          ]
        )

      assert %DistanceModel{
               person_id: person.id,
               candidate_id: clone.id,
               distance_second_name: 0,
               distance_first_name: 1,
               distance_last_name: 2,
               distance_documents: 1,
               docs_same_number: 0,
               birth_settlement_substr: 0,
               distance_tax_id: 1,
               residence_settlement_flag: 0,
               registration_address_settlement_flag: 0,
               authentication_methods_flag: 0,
               gender_flag: 0,
               twins_flag: 0
             } == CandidatesDistance.levenshtein_weight(person, clone)
    end

    test "levenshtein_weight for twins persons works" do
      person =
        build(:person,
          id: UUID.generate(),
          gender: "male",
          tax_id: "1123456789",
          first_name: "Іван",
          last_name: "Іванів",
          second_name: "Петрович",
          birth_date: ~D[1996-12-12],
          birth_settlement: "смт. Рокита",
          documents: [%{type: "PASSPORT", document: "упп7423", number: "7423"}],
          authentication_methods: [%{"phone_number" => "123", "type" => "OTP"}],
          addresses: [
            %{type: "REGISTRATION", settlement: "0123"},
            %{type: "RESIDENCE", settlement: "4567"}
          ]
        )

      clone =
        build(:person,
          id: UUID.generate(),
          gender: "male",
          tax_id: "0123456789",
          first_name: "Ів",
          last_name: "Іванов",
          second_name: nil,
          birth_date: ~D[1996-12-12],
          birth_settlement: "Рокита",
          documents: [%{type: "PASSPORT", document: "пп7422", number: "7422"}],
          authentication_methods: [%{"phone_number" => "9999", "type" => "OTP"}],
          addresses: [
            %{type: "REGISTRATION", settlement: "0123"},
            %{type: "RESIDENCE", settlement: "4567"}
          ]
        )

      assert %DistanceModel{
               person_id: person.id,
               candidate_id: clone.id,
               distance_second_name: nil,
               distance_first_name: 2,
               distance_last_name: 1,
               distance_documents: 2,
               docs_same_number: 1,
               birth_settlement_substr: 0,
               distance_tax_id: 1,
               residence_settlement_flag: 0,
               registration_address_settlement_flag: 0,
               authentication_methods_flag: 1,
               gender_flag: 0,
               twins_flag: 1
             } == CandidatesDistance.levenshtein_weight(person, clone)
    end
  end

  describe "finalize distance functions" do
    test "d_tax_id_woe works" do
      assert -0.217612736 == CandidatesDistance.d_tax_id_woe(nil)
      assert -2.714837812 == CandidatesDistance.d_tax_id_woe(0)
      assert 2.305107806 == CandidatesDistance.d_tax_id_woe(1)
      assert 2.305107806 == CandidatesDistance.d_tax_id_woe(2)
      assert 2.305107806 == CandidatesDistance.d_tax_id_woe(3)
    end

    test "d_documents_woe works" do
      assert -2.12133861 == CandidatesDistance.d_documents_woe(0)
      assert 0.907611604 == CandidatesDistance.d_documents_woe(1)
      assert 0.907611604 == CandidatesDistance.d_documents_woe(2)
      assert 0.907611604 == CandidatesDistance.d_documents_woe(3)
      assert 1.957050787 == CandidatesDistance.d_documents_woe(nil)
      assert 1.957050787 == CandidatesDistance.d_documents_woe(4)
      assert 1.957050787 == CandidatesDistance.d_documents_woe(5)
      assert 1.957050787 == CandidatesDistance.d_documents_woe(6)
      assert 2.559220981 == CandidatesDistance.d_documents_woe(7)
      assert 2.559220981 == CandidatesDistance.d_documents_woe(110)
    end

    test "d_second_name_woe works" do
      assert -0.988391454 == CandidatesDistance.d_second_name_woe(nil)
      assert -1.405398133 == CandidatesDistance.d_second_name_woe(0)
      assert -1.405398133 == CandidatesDistance.d_second_name_woe(1)
      assert -1.405398133 == CandidatesDistance.d_second_name_woe(2)
      assert 2.050493088 == CandidatesDistance.d_second_name_woe(3)
      assert 2.050493088 == CandidatesDistance.d_second_name_woe(4)
      assert 2.589141853 == CandidatesDistance.d_second_name_woe(5)
      assert 2.589141853 == CandidatesDistance.d_second_name_woe(11)
    end

    test "d_last_name_woe works" do
      assert -1.181889463 == CandidatesDistance.d_last_name_woe(0)
      assert -1.181889463 == CandidatesDistance.d_last_name_woe(1)
      assert -0.716750603 == CandidatesDistance.d_last_name_woe(2)
      assert 3.421035127 == CandidatesDistance.d_last_name_woe(nil)
      assert 3.421035127 == CandidatesDistance.d_last_name_woe(3)
      assert 3.421035127 == CandidatesDistance.d_last_name_woe(4)
    end

    test "d_first_name_woe works" do
      assert -2.801009159 == CandidatesDistance.d_first_name_woe(0)
      assert -1.379763317 == CandidatesDistance.d_first_name_woe(1)
      assert 0.896797543 == CandidatesDistance.d_first_name_woe(2)
      assert 4.278408035 == CandidatesDistance.d_first_name_woe(3)
      assert 4.278408035 == CandidatesDistance.d_first_name_woe(4)
    end

    test "docs_same_number_woe works" do
      assert -2.065190805 == CandidatesDistance.docs_same_number_woe(0)
      assert 1.485675379 == CandidatesDistance.docs_same_number_woe(nil)
      assert 1.485675379 == CandidatesDistance.docs_same_number_woe(1)
    end

    test "birth_settlement_substr_woe works" do
      assert -1.033368721 == CandidatesDistance.birth_settlement_substr_woe(0)
      assert 1.625216412 == CandidatesDistance.birth_settlement_substr_woe(nil)
      assert 1.625216412 == CandidatesDistance.birth_settlement_substr_woe(42)
    end

    test "authentication_methods_flag_woe works" do
      assert -0.962223178 == CandidatesDistance.authentication_methods_flag_woe(0)
      assert 1.242406002 == CandidatesDistance.authentication_methods_flag_woe(nil)
      assert 1.242406002 == CandidatesDistance.authentication_methods_flag_woe(1)
    end

    test "residence_settlement_flag_woe works" do
      assert -0.906624219 == CandidatesDistance.residence_settlement_flag_woe(0)
      assert 2.312877566 == CandidatesDistance.residence_settlement_flag_woe(nil)
      assert 2.312877566 == CandidatesDistance.residence_settlement_flag_woe(1)
    end

    test "registration_address_settlement_flag_woe works" do
      assert -0.937089181 == CandidatesDistance.registration_address_settlement_flag_woe(0)
      assert 2.456584084 == CandidatesDistance.registration_address_settlement_flag_woe(nil)
      assert 2.456584084 == CandidatesDistance.registration_address_settlement_flag_woe(1)
    end

    test "gender_flag_woe works" do
      assert -0.43537168 == CandidatesDistance.gender_flag_woe(0)
      assert 2.886330559 == CandidatesDistance.gender_flag_woe(nil)
      assert 2.886330559 == CandidatesDistance.gender_flag_woe(1)
    end

    test "twins_flag_woe works" do
      assert -0.159950822 == CandidatesDistance.twins_flag_woe(0)
      assert 7.817262167 == CandidatesDistance.twins_flag_woe(nil)
      assert 7.817262167 == CandidatesDistance.twins_flag_woe(1)
    end
  end

  describe "finalize model" do
    test "finalize_weight works" do
      person_id = UUID.generate()
      candidate_id = UUID.generate()

      assert %{
               person_id: person_id,
               candidate_id: candidate_id,
               d_first_name_woe: 4.278408035,
               d_second_name_woe: -0.988391454,
               d_last_name_woe: -1.181889463,
               d_documents_woe: -2.12133861,
               docs_same_number_woe: -2.065190805,
               birth_settlement_substr_woe: 1.625216412,
               d_tax_id_woe: 2.305107806,
               residence_settlement_flag_woe: 2.312877566,
               registration_address_settlement_flag_woe: 2.456584084,
               authentication_methods_flag_woe: -0.962223178,
               gender_flag_woe: 2.886330559,
               twins_flag_woe: -0.159950822
             } ==
               CandidatesDistance.finalize_weight(%DistanceModel{
                 person_id: person_id,
                 candidate_id: candidate_id,
                 distance_first_name: 12,
                 distance_second_name: nil,
                 distance_last_name: 0,
                 distance_documents: 0,
                 docs_same_number: 0,
                 birth_settlement_substr: 42,
                 distance_tax_id: 1,
                 residence_settlement_flag: 4,
                 registration_address_settlement_flag: 2,
                 authentication_methods_flag: 0,
                 gender_flag: 1,
                 twins_flag: 0
               })
    end
  end
end
