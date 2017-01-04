defmodule Test.Fugue.Error do
  defexception [:message]

  defimpl Plug.Exception do
    def status(_) do
      400
    end
  end
end

defmodule Test.Fugue.Subject do
  import Plug.Conn
  use Plug.ErrorHandler

  def init(options) do
    # initialize options

    options
  end

  def call(%{request_path: "/error"}, _opts) do
    raise Test.Fugue.Error, "Uh oh!"
  end
  def call(%{request_path: "/wrapped-error"} = conn, _opts) do
    exception = %Test.Fugue.Error{message: "Uh oh!"}
    raise Plug.Conn.WrapperError, conn: conn, kind: :error, reason: exception, stack: []
  end
  def call(%{request_path: "/json"} = conn, _opts) do
    conn
    |> put_resp_content_type("application/json")
    |> send_resp(200, Poison.encode!(%{"hello" => "world"}))
  end
  def call(conn, _opts) do
    conn
    |> put_resp_content_type("text/plain")
    |> put_resp_header("location", "http://#{conn.host}/foo")
    |> send_resp(200, "Hello, World!")
  end
end

ExUnit.start()
