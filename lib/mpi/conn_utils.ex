defmodule MPI.ConnUtils do
   @header_consumer_id "x-consumer-id"

  def get_consumer_id(%Plug.Conn{req_headers: req_headers}) do
    get_header(req_headers, @header_consumer_id)
  end

  defp get_header(headers, header) when is_list(headers) do
    case List.keyfind(headers, header, 0) do
      nil -> nil
      {_key, val} -> val
    end
  end
end