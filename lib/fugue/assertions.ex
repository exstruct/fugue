defmodule Fugue.Assertions do
  import ExUnit.Assertions

  for call <- [:assert, :refute] do
    def unquote(:"#{call}_status")(conn, status_code) do
      a = conn.status
      e = status_code
      ExUnit.Assertions.unquote(call)(a == e, [
        lhs: a,
        message: "Expected status code #{inspect(e)}, got #{inspect(a)}"])
      conn
    end

    def unquote(:"#{call}_success_status")(conn) do
      a = conn.status
      ExUnit.Assertions.unquote(call)(a < 400, [
        lhs: a,
        message: "Expected status code #{inspect(a)} to be successful (< 400)"])
      conn
    end

    def unquote(:"#{call}_error_status")(conn) do
      a = conn.status
      ExUnit.Assertions.unquote(call)(a >= 400, [
        lhs: a,
        message: "Expected status code #{inspect(a)} to be an error (>= 400)"])
      conn
    end

    def unquote(:"#{call}_body")(conn, body) do
      ExUnit.Assertions.unquote(call)(conn.resp_body == body)
      conn
    end

    def unquote(:"#{call}_body_contains")(conn, body) do
      a = conn.resp_body
      e = body

      indented = fn ->
        a
        |> String.split("\n")
        |> Enum.map(&("    " <> &1))
        |> Enum.join("\n")
      end

      contains? = if Regex.regex?(body) do
        Regex.match?(e, a)
      else
        String.contains?(a, e)
      end

      ExUnit.Assertions.unquote(call)(contains?, [
        lhs: a,
        rhs: e,
        message: "Expected response body to contain #{inspect(e)}, got:\n#{indented.()}"])
      conn
    end

    def unquote(:"#{call}_transition")(conn, "/" <> _ = path) do
      unquote(:"#{call}_transition")(conn, %URI{scheme: to_string(conn.scheme), host: conn.host, port: conn.port, path: path})
    end
    def unquote(:"#{call}_transition")(conn, expected) when is_binary(expected) do
      unquote(:"#{call}_transition")(conn, URI.parse(expected))
    end
    def unquote(:"#{call}_transition")(conn, expected) do
      actual = case get_header(conn, "location") do
        nil ->
          nil
        actual ->
          uri = URI.parse(actual)
      end

      equals? = (actual.scheme || to_string(conn.scheme)) == expected.scheme &&
                (actual.host || conn.host) == expected.host &&
                (actual.port || conn.port) == expected.port &&
                actual.path == expected.path

      ExUnit.Assertions.unquote(call)(equals?, [
        lhs: actual,
        rhs: expected,
        message: "Expected transition to #{expected} but got #{actual}"])
      conn
    end
  end

  defp get_header(conn, name) do
    case :lists.keyfind(name, 1, conn.resp_headers) do
      false ->
        nil
      {_, value} ->
        value
    end
  end
end
