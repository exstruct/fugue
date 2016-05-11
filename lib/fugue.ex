defmodule Fugue do
  defmacro __using__(opts) do
    plug = opts[:plug]
    plug_opts = opts[:plug_opts] || []
    async = Keyword.get(opts, :async, false)

    quote do
      use ExUnit.Case, async: unquote(async)
      import ExUnit.Case, only: [test: 1] # unimport ExUnit.Case so we can override 'test'
      import unquote(__MODULE__)
      import unquote(__MODULE__).Assertions
      import unquote(__MODULE__).Request

      if Code.ensure_loaded?(Plug.Conn) || function_exported?(Plug.Conn, :__struct__, 0) do
        defp init_request(_) do
          Plug.Conn.__struct__()
          |> Map.merge(%{request_path: "/",
                         req_headers: [{"accept", "*/*"}]})
        end

        defp prepare_request(conn) do
          Plug.Adapters.Test.Conn.conn(conn, conn.method || "GET", conn.request_path || "/", nil)
        end
      else
        defp init_request(_) do
          nil
        end

        defp prepare_request(conn) do
          conn
        end
      end

      defoverridable init_request: 1, prepare_request: 1

      if unquote(plug) do
        @fugue_plug_opts unquote(plug).init(unquote(plug_opts))
        defp call(request) do
          unquote(plug).call(request, @fugue_plug_opts)
        end
        defoverridable call: 1
      else
        def call(request) do
          request
        end
      end

      defp execute(request, assertions) do
        request
        |> call()
        |> assertions.()
      end
      defoverridable execute: 2
    end
  end

  defmacro test(name, [do: block]) do
    quote do
      ExUnit.Case.test(unquote(name), do: unquote(block))
    end
  end

  defmacro test(name, [do: _, after: _] = body) do
    quote do
      test(unquote(name), unquote(Macro.var(:_, nil)), unquote(body))
    end
  end

  defmacro test(name, context, [do: block]) do
    quote do
      ExUnit.Case.test(unquote(name), unquote(context), do: unquote(block))
    end
  end

  defmacro test(name, context, [do: block, after: assertions]) do
    quote do
      ExUnit.Case.test unquote(name), var!(fugue_context) do
        unquote(context) = var!(fugue_context)

        request = unquote(block)
        assertions = unquote({:fn, [], assertions})

        request
        |> prepare_request()
        |> execute(assertions)
      end
    end
  end

  defmacro request(body \\ [do: nil]) do
    quote do
      var!(fugue_context)
      |> init_request()
      |> request(unquote(body))
    end
  end
end
