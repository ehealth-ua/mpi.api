defmodule PersonDeactivator.EventManager do
  @moduledoc false

  @type_change_status "StatusChangeEvent"

  def new_event(entity, user_id, status, event_type \\ @type_change_status) do
    entity_type =
      entity.__struct__
      |> Module.split()
      |> List.last()

    %{
      event_type: event_type,
      entity_type: entity_type,
      entity_id: entity.id,
      properties: %{"status" => %{"new_value" => status}},
      event_time: NaiveDateTime.utc_now(),
      changed_by: user_id
    }
  end
end
