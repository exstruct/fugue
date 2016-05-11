defmodule FugueSubject do
  import Plug.Conn

  def init(options) do
    # initialize options

    options
  end

  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("location", "http://#{conn.host}/foo")
    |> send_resp(200, "Hello, World!")
  end
end

ExUnit.start()
