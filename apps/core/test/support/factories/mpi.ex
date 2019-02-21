defmodule Core.Factories.MPI do
  @moduledoc """
  This module lists factories, a mean suitable
  for tests that involve preparation of DB data
  """
  defmacro __using__(_opts) do
    quote do
      alias Ecto.UUID
      alias Core.MergeCandidate
      alias Core.Person
      alias Core.PersonAddress
      alias Core.PersonDocument
      alias Core.PersonPhone
      alias Core.PersonUpdate
      alias Core.VerifyingIds

      @person_status_active Person.status(:active)

      def merge_candidate_factory do
        %MergeCandidate{
          status: "NEW",
          config: %{},
          person: build(:person),
          master_person: build(:person),
          score: 0.9
        }
      end

      def person_factory do
        birthday = ~D[1996-12-12]
        first_name = first_name()
        last_name = last_name()

        %Person{
          version: "0.1",
          first_name: first_name,
          last_name: last_name,
          second_name: second_name(),
          birth_date: birthday,
          birth_country: sequence(:birth_country, &"birth_country-#{&1}"),
          birth_settlement: city(),
          gender: Enum.random(["MALE", "FEMALE"]),
          email: sequence(:email, &"email#{&1}@mail.com"),
          tax_id: document_number(9),
          no_tax_id: false,
          unzr: sequence(:unzr, &"#{birthday}-#{&1}"),
          death_date: ~D[2117-11-09],
          preferred_way_communication: "email",
          is_active: true,
          secret: sequence(:secret, &"secret-#{&1}"),
          emergency_contact: build(:emergency_contact),
          confidant_person: build_list(1, :confidant_person),
          patient_signed: true,
          process_disclosure_data_consent: true,
          status: @person_status_active,
          inserted_by: UUID.generate(),
          updated_by: UUID.generate(),
          authentication_methods: build_list(2, :authentication_method),
          merged_ids: [],
          phones: build_list(1, :person_phone),
          documents: build_list(2, :person_document),
          addresses: build_list(2, :person_address, person_first_name: first_name, person_last_name: last_name)
        }
      end

      def person_update_factory do
        %PersonUpdate{
          person_id: UUID.generate(),
          status: Person.status(:active),
          updated_by: UUID.generate()
        }
      end

      def person_address_factory do
        %PersonAddress{
          person_first_name: first_name(),
          person_last_name: last_name(),
          type: "RESIDENCE",
          country: "UA",
          area: region(),
          region: region(),
          settlement: city(),
          settlement_type: "city",
          settlement_id: UUID.generate(),
          street_type: street_type(),
          street: street(),
          building: "#{Enum.random(1..120)}",
          apartment: "#{Enum.random(1..24)}",
          zip: "#{Enum.random(10000..99999)}"
        }
      end

      def person_document_factory do
        Map.merge(
          %PersonDocument{},
          make_document(Enum.random(~w(PASSPORT NATIONAL_ID BIRTH_CERTIFICATE)))
        )
      end

      def person_phone_factory do
        %PersonPhone{
          person_id: UUID.generate(),
          type: Enum.random(["MOBILE", "LANDLINE"]),
          number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}"
        }
      end

      def emergency_contact_factory do
        %{
          first_name: first_name(),
          last_name: last_name(),
          second_name: second_name(),
          phones: build_list(1, :phone)
        }
      end

      def confidant_person_factory do
        %{
          relation_type: Enum.random(["PRIMARY", "SECONDARY"]),
          first_name: first_name(),
          last_name: last_name(),
          second_name: second_name(),
          birth_date: "1996-12-12",
          birth_country: sequence(:confidant_person_birth_country, &"birth_country-#{&1}"),
          birth_settlement: sequence(:confidant_person_birth_settlement, &"birth_settlement-#{&1}"),
          gender: Enum.random(["MALE", "FEMALE"]),
          tax_id: sequence(:confidant_person_tax_id, &"tax_id-#{&1}"),
          secret: sequence(:confidant_person_secret, &"secret-#{&1}"),
          phones: build_list(1, :phone),
          documents_person: build_list(2, :document),
          documents_relationship: build_list(2, :document)
        }
      end

      def document_factory do
        make_document(Enum.random(~w(PASSPORT NATIONAL_ID BIRTH_CERTIFICATE)))
      end

      def phone_factory do
        %{
          type: Enum.random(["MOBILE", "LANDLINE"]),
          number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}"
        }
      end

      def authentication_method_factory do
        %{
          type: Enum.random(["OTP", "OFFLINE"]),
          phone_number: "+38#{Enum.random(1_000_000_000..9_999_999_999)}"
        }
      end

      def verifying_ids_factory do
        %VerifyingIds{id: UUID.generate()}
      end

      defp make_document("NATIONAL_ID") do
        %{
          type: "NATIONAL_ID",
          number: document_number(9),
          issued_by: document_number(4),
          issued_at: add_random_years(0, 2, -1),
          expiration_date: add_random_years(10, 12)
        }
      end

      defp make_document("PASSPORT") do
        %{
          type: "PASSPORT",
          number: "#{random_letter()}#{random_letter()}#{document_number(6)}",
          issued_by: "#{city()} РОУ ВМУ МВС в #{region()} області",
          issued_at: add_random_years(2, 10, -1)
        }
      end

      defp make_document("BIRTH_CERTIFICATE") do
        %{
          type: "BIRTH_CERTIFICATE",
          number:
            1..16
            |> Enum.map(fn _ -> random_letter() end)
            |> Enum.join(random_letter()),
          issued_by: "#{city()} РОУ ВМУ МВС в #{region()} області",
          issued_at: add_random_years(0, 16, -1),
          expiration_date: add_random_years(0, 16)
        }
      end

      defp add_random_years(min, max, koef \\ 1),
        do: Date.utc_today() |> Date.add(koef * Enum.random(min..max) * 365) |> Date.to_string()

      defp document_number(length) do
        min = Kernel.trunc(:math.pow(10, length - 1))
        max = Kernel.trunc(:math.pow(10, length)) - 1
        min..max |> Enum.random() |> Integer.to_string()
      end

      defp random_letter do
        List.to_string([Enum.random(?А..?Я)])
      end

      defp first_name do
        Enum.random(
          ~w(Абель Анатолій Богдана Володимир Денис Ґанна Едуард Леон Лук'ян Максім Мар'ян Наталія Назарій Олекса Орест Пилип Полина Пантелеймон Руслана Світлана Юлія Юрій Яків Ярослав)
        )
      end

      defp last_name do
        Enum.random(
          ~w(Біланюк Бабенко Балясний Банах Бар'яхтар Басок Борис Бахрушин Бернацький Боголюбов Богорош Бойко Бойчук Борзяк Боровик Бурак Бушок
      Самойлович Анатолій Григорович Сандул Сахнович Свідзинський Семиноженко  Синельников Ситенко Сігорський Скалозуб Скоробогатько Слободянюк Смакула Сминтина Смирнов Соколов Соколовський Стасів Стасюк Сторіжко Стріха Сукач
      Файнберг Федоровський Федорченко Флейшман Фомін Фуртак Шайкевич Шелест Шиманський Шимон Шпак Шпачинський Шутенко)
        )
      end

      defp second_name do
        Enum.random(
          ~w(Володимирович Григівна Євгенович Іванівна Йосипович Калістратрівна Костянтинович Корнелійович Миколаївна Олександрович Пилипівна Станіславович Степановна Терентійович Федорівна)
        )
      end

      defp region do
        Enum.random(
          ~w(Київ Київська Черкаська Чернігівська Чернівецька Січеславська Донецька Івано-Франківська Харківська Херсонська Хмельницька Кропивницька Луганьска Львівська Міколаївська Одеська Полтавська Рівненська Сумська Тернопільска Вінницька Волиньска Закарпаться Запоріжська Житомирська)
        )
      end

      defp city do
        Enum.random(
          ~w(Київ Черкаси Чернігів Чернівці Дніпро Донецьк Івано-Франківськ Харків Херсон Хмельницьк Кропивницький Луганьс Львів Міколаїв Одеса Полтава Рівне Суми Тернопіль Вінниця Луцьк Ужгород Запоріжжя Житомир)
        )
      end

      defp street_type do
        Enum.random(~w(проспект вулиця провулок))
      end

      defp street do
        Enum.random(~w(Героїв Перемоги Бандери))
      end
    end
  end
end
