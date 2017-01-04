defmodule Fugue.Assertions do
  import ExUnit.Assertions

  for call <- [:assert, :refute] do
    def unquote(:"#{call}_status")(conn, status_code) do
      a = conn.status
      e = status_code
      ExUnit.Assertions.unquote(call)(a == e, [
        left: a,
        message: "Expected status code #{inspect(e)}, got #{inspect(a)}"])
      conn
    end

    def unquote(:"#{call}_success_status")(conn) do
      a = conn.status
      ExUnit.Assertions.unquote(call)(a < 400, [
        left: a,
        message: "Expected status code #{inspect(a)} to be successful (< 400)"])
      conn
    end

    def unquote(:"#{call}_error_status")(conn) do
      a = conn.status
      ExUnit.Assertions.unquote(call)(a >= 400, [
        left: a,
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
        left: a,
        right: e,
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
          %URI{}
        actual ->
          URI.parse(actual)
      end

      equals? = (actual.scheme || to_string(conn.scheme)) == expected.scheme &&
                (actual.host || conn.host) == expected.host &&
                (actual.port || conn.port) == expected.port &&
                actual.path == expected.path

      ExUnit.Assertions.unquote(call)(equals?, [
        left: actual,
        right: expected,
        message: "Expected transition to #{expected} but got #{actual}"])
      conn
    end

    defmacro unquote(:"#{call}_json")(conn, match) do
      call = unquote(call)

      quote do
        conn = unquote(conn)
        parsed_body = conn.private[:fugue_resp_json_body] || Poison.decode!(conn.resp_body)
        conn = Plug.Conn.put_private(conn, :fugue_resp_json_body, parsed_body)

        unquote(:"#{call}_term_match")(parsed_body, unquote(match), "Expected JSON response body to match")

        conn
      end
    end
  end

  defmacro assert_term_match(actual, expected, message \\ "Term match failed") do
    expected_code = expected |> Macro.escape()
    {expected, vars, aliases} = format_match(expected)

    quote do
      actual = unquote(actual)
      expected_code = unquote(expected_code)

      unquote_splicing(vars)

      ExUnit.Assertions.assert(match?(unquote(expected), actual), [
        expr: quote do
          unquote(expected_code) = unquote(Macro.escape(actual))
        end,
        message: unquote(message)
      ])

      unquote(expected) = actual
      unquote_splicing(aliases)

      actual
    end
  end

  defmacro refute_term_match(actual, expected, message \\ "Term match expected to fail") do
    expected_code = expected |> Macro.escape()
    {expected, vars, _} = format_match(expected)

    quote do
      actual = unquote(actual)
      expected_code = unquote(expected_code)

      unquote_splicing(vars)

      ExUnit.Assertions.refute(match?(unquote(expected), actual), [
        expr: quote do
          unquote(expected_code) = unquote(Macro.escape(actual))
        end,
        message: unquote(message)
      ])

      actual
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

  @term_match :__fugue_term_match__
  @term_vars :__fugue_term_vars__

  defp format_match(ast) do
    ast = Macro.prewalk(ast, fn
      ({_, [{unquote(@term_match), true} | _], _} = expr) ->
        expr
      ({call, _, context} = expr) when is_atom(call) and is_atom(context) and call != :_ ->
        acc_var(expr)
      ({call, _, _} = expr) when is_tuple(call) ->
        acc(expr)
      ({call, _, _} = expr) when not call in [:{}, :%{}, :_, :|, :^, :=, :<>] ->
        acc(expr)
      ({:^, meta, [{var, var_meta, var_context}]}) ->
        {:^, meta, [{var, [{@term_match, true} | var_meta], var_context}]}
      (expr) ->
        expr
    end)
    {ast, acc(), acc_var()}
  end
  defp acc do
    Process.delete(@term_match) || []
  end
  defp acc(expr) do
    acc = Process.get(@term_match, [])
    var = {:"_@term_#{length(acc)}", [{@term_match, true}], __MODULE__}
    Process.put(@term_match, [quote do
                                unquote(var) = unquote(expr)
                              end | acc])
    {:^, [{@term_match, true}], [var]}
  end

  defp acc_var do
    Process.delete(@term_vars) || []
  end
  defp acc_var(var) do
    acc = Process.get(@term_vars, [])
    alias_var = Macro.var(:"_@term_alias_#{length(acc)}", __MODULE__)
    Process.put(@term_vars, [quote do
                               unquote(var) = unquote(alias_var)
                             end | acc])
    alias_var
  end
end
