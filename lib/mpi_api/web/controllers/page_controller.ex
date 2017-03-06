defmodule MpiApi.Web.PageController do
  use MpiApi.Web, :controller

  def index(conn, _params) do
    render conn, "index.html"
  end
end
