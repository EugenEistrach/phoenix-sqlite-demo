defmodule PhoenixSqliteDemoWeb.PageController do
  use PhoenixSqliteDemoWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
