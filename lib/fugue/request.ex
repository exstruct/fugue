defmodule Fugue.Request do
  defmacro request(conn, [do: block]) do
    quote do
      var!(conn) = unquote(conn)
      unquote(block)
      var!(conn)
    end
  end

  defmacro conn_put(key, value) do
    quote do
      var!(conn) = Map.put(var!(conn), unquote(key), unquote(value))
    end
  end

  defmacro method(method) do
    quote do
      method = unquote(method) |> to_string() |> String.upcase()
      conn_put(:method, method)
    end
  end

  defmacro host(host) do
    quote do
      conn_put(:host, unquote(host))
    end
  end

  defmacro path(path) do
    quote do
      conn_put(:request_path, unquote(path))
    end
  end

  defmacro header(kvs) do
    quote do
      headers = Map.get(var!(conn), :req_headers, [])
      kvs = Enum.map(unquote(kvs), fn {k, v} -> {to_string(k), to_string(v)} end)
      var!(conn) = Map.put(var!(conn), :req_headers, kvs ++ headers)
    end
  end

  defmacro header(key, value) do
    quote do
      header([{unquote(key), unquote(value)}])
    end
  end

  defmacro accept(type) do
    quote do
      {:ok, [{type, subtype, params}]} =
        case unquote(type) do
          type when is_binary(type) ->
            type |> :mimetype_parser.parse()
          type when is_atom(type) ->
            type |> to_string |> :mimetype_parser.parse()
          {_, _, _} = type ->
            {:ok, [type]}
        end

      accept(type, subtype, params)
    end
  end

  defmacro accept(type, subtype, params \\ Macro.escape(%{})) do
    quote do
      type = unquote(type)
      subtype = unquote(subtype)
      params = unquote(params)
      accept = cond do
        map_size(params) == 0 ->
          "#{type}/#{subtype}"
        true ->
          params = Enum.map(params, fn {k, v} -> "#{k}=#{v}" end) |> Enum.join("; ")
          "#{type}/#{subtype}; #{params}"
      end
      header("accept", accept)
    end
  end

  defmacro ip(ip) do
    quote do
      ip =
        case unquote(ip) do
          ip when is_tuple(ip) ->
            ip
          ip ->
            {:ok, ip} = ip |> to_char_list() |> :inet.parse_address()
            ip
        end

      conn_put(:remote_ip, ip)
    end
  end
end
