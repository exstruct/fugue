defmodule Fugue do
  defmacro __using__(opts) do
    plug = opts[:plug]
    plug_opts = opts[:plug_opts] || []
    ui = opts[:ui] || ExUnit.Case
    ui_opts = opts[:ui_opts] || []

    # unimport the interface so we can override 'test'
    ui_unimport = function_exported?(ui, :test, 1)
      && [test: 1]
      || []

    quote do
      use unquote(ui), unquote(ui_opts)
      import unquote(ui), only: unquote(ui_unimport)
      import unquote(__MODULE__)
      import unquote(__MODULE__).Assertions
      import unquote(__MODULE__).Request

      if Code.ensure_loaded?(Plug.Conn) || function_exported?(Plug.Conn, :__struct__, 0) do
        defp init_request(_context) do
          Plug.Conn.__struct__()
          |> Map.merge(%{request_path: "/",
                         req_headers: [{"accept", "*/*"}]})
        end

        defp prepare_request(conn, _context) do
          Plug.Adapters.Test.Conn.conn(
            conn,
            conn.method || "GET",
            conn.request_path || "/",
            conn.private[:fugue_body]
          )
        end
      else
        defp init_request(_context) do
          nil
        end

        defp prepare_request(conn, _context) do
          conn
        end
      end

      defoverridable init_request: 1, prepare_request: 2

      if unquote(plug) do
        @fugue_plug_opts unquote(plug).init(unquote(plug_opts))
        defp call(request, _context) do
          unquote(plug).call(request, @fugue_plug_opts)
        end
      else
        def call(request, _context) do
          request
        end
      end
      defoverridable call: 2

      defp execute(request, assertions, context) do
        request
        |> call(context)
        |> assertions.()
      end
      defoverridable execute: 3
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
        |> prepare_request(var!(fugue_context))
        |> execute(assertions, var!(fugue_context))
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
