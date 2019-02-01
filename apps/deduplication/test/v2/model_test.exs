defmodule Deduplication.V2.ModelTest do
  use Core.ModelCase, async: false
  import Core.Factory

  alias Core.Person
  alias Deduplication.V2.Match
  alias Deduplication.V2.Model

  describe "regexp" do
    test "normalize_text works" do
      refute Model.normalize_text(nil)
      assert "еґфїф" == Model.normalize_text("‐єҐ-ф--Ї—ф")
    end

    test "normalize_birth_certificate_document works" do
      refute Model.normalize_birth_certificate_document(nil)
      assert "1їєґфф21345ї" == Model.normalize_birth_certificate_document("іЇє ҐфФ‐21345---Ї—")
    end

    test "normalize_document_number works" do
      refute Model.normalize_document_number(nil)
      assert "іїєґфф21345ї" == Model.normalize_document_number("іЇ єҐфФ‐21345---Ї—")
    end

    test "document_number works" do
      refute Model.document_number(nil)
      assert "21345" == Model.document_number("іЇ єҐфФ‐21345---Ї—")
    end

    test "document_number returns nil for number containing letters only" do
      refute Model.document_number(nil)
      assert nil == Model.document_number("іфФ ‐Ї-є-Ґ-Ї—")
    end

    test "normalize_birth_settlement works" do
      Enum.each(
        ["с Циблі", "C Циблі", "С.Циблі", "c.Циблі", "с,Циблі", "C,Циблі"],
        &assert(Model.normalize_birth_settlement(&1) == "ціблі")
      )

      Enum.each(
        ["село.Циблі", "Cело.Циблі", "СЕЛО,Циблі", "cело,Циблі", "село Циблі", "CЕЛО Циблі"],
        &assert(Model.normalize_birth_settlement(&1) == "ціблі")
      )

      Enum.each(
        ["село.Циблі", "Cело.Циблі", "СЕЛО,Циблі", "cело,Циблі", "село Циблі", "CЕЛО Циблі"],
        &assert(Model.normalize_birth_settlement(&1) == "ціблі")
      )

      Enum.each(
        ["селищеЦиблі", "СелищеЦиблі", "CЕЛИЩЕЦиблі"],
        &assert(Model.normalize_birth_settlement(&1) == "ціблі")
      )

      Enum.each(
        [
          "СМТ Рокитне",
          "CМТ.Рокитне",
          "смт,Рокитне",
          "cелище мicького типуРокитне",
          "СЕЛИЩЕ MICЬКОГО ТИПУРокитне",
          "Селище Міського ТипуРокитне"
        ],
        &assert(Model.normalize_birth_settlement(&1) == "рокітне")
      )

      Enum.each(
        [
          "м Тернопіль",
          "M.Тернопіль",
          "м,Тернопіль",
          "MICTO Тернопіль",
          "Micто,Тернопіль",
          "місто. Тернопіль"
        ],
        &assert(Model.normalize_birth_settlement(&1) == "тернопіль")
      )
    end
  end

  describe "unverified person by tax_id" do
    setup do
      Match.set_current_verified_ts(DateTime.utc_now())
      :ok
    end

    test "get unverified person works" do
      person = insert(:mpi, :person, tax_id: "123456789")
      [unverified_person] = Model.get_unverified_persons(1)

      assert person.id == unverified_person.id
    end

    test "normalize unverified person works" do
      person = insert(:mpi, :person, tax_id: "123456789")
      [unverified_person] = Model.get_unverified_persons(10)
      unverified_person = Model.normalize_person(unverified_person)
      assert person.id == unverified_person.id

      Enum.each(unverified_person.documents, fn document ->
        assert %{document: _, number: _, type: _} = document
      end)
    end

    test "unverified persons limit" do
      insert(:mpi, :person)
      Match.set_current_verified_ts(DateTime.utc_now())
      assert [] == Model.get_unverified_persons(1)

      Match.set_current_verified_ts(DateTime.utc_now())
      person = insert(:mpi, :person)
      assert [%Person{id: id}] = Model.get_unverified_persons(1)
      assert id == person.id
      assert [%Person{}] = Model.get_unverified_persons(5)
    end

    test "get candidates works" do
      p00 = insert(:mpi, :person, tax_id: "000000000").id
      insert(:mpi, :person, tax_id: "999999999")
      p10 = insert(:mpi, :person, tax_id: "123456789").id

      Match.set_current_verified_ts(DateTime.utc_now())

      p11 =
        insert(:mpi, :person, tax_id: "123456789", documents: [build(:document, number: "1")]).id

      insert(:mpi, :person, tax_id: "123456789", documents: [build(:document, number: "2")])

      p01 =
        insert(:mpi, :person, tax_id: "000000000", documents: [build(:document, number: "3")]).id

      insert(:mpi, :person, tax_id: "000000000", documents: [build(:document, number: "4")])
      unverified_persons = Model.get_unverified_persons(100)

      Enum.reduce(unverified_persons, 1, fn unverified_person, i ->
        case i do
          1 ->
            assert [%Person{id: ^p10, tax_id: "123456789"}] =
                     Model.get_candidates(unverified_person)

          2 ->
            assert [
                     %Person{id: ^p10, tax_id: "123456789"},
                     %Person{id: ^p11, tax_id: "123456789"}
                   ] = Model.get_candidates(unverified_person)

          3 ->
            assert [%Person{id: ^p00, tax_id: "000000000"}] =
                     Model.get_candidates(unverified_person)

          4 ->
            assert [
                     %Person{id: ^p00, tax_id: "000000000"},
                     %Person{id: ^p01, tax_id: "000000000"}
                   ] = Model.get_candidates(unverified_person)
        end

        i + 1
      end)
    end
  end
end
