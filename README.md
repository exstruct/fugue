# fugue

Plug testing utilities

## Installation

`Fugue` is [available in Hex](https://hex.pm/docs/publish) and can be installed as:

  1. Add concerto your list of dependencies in `mix.exs`:

        def deps do
          [{:fugue, "~> 0.1.0"}]
        end

## Usage

Fugue extends ExUnit by adding macros for calling Plug applications in an extendable way.

```elixir
defmodule Test.MyApp do
  use Fugue, plug: MyApp

  test "root response" do
    request()
  after conn ->
    conn
    |> assert_status(200)
  end

  test "users read response" do
    user_id = "123" # this could come from a seed function

    request do
      path "/users/#{user_id}"
    end
  after conn ->
    conn
    |> assert_body_contains(user_id)
  end
end
```

Notice the setup and assertions are separated by an `after` keyword. The idea is to decouple the test case setup/generation from the actual test case execution. This ends up being useful in many ways:

* We could generate cases on a single machine and distribute the requests around a cluster
* We could create benchmarks that exclude the setup time and just test the request rate (maybe even skip assertions entirely)
* We could serialize the requests into a file and run at a later time, or in a different language or service
* _insert your crazy idea here_

`Fugue` exposes several overridable functions to support this behavior:

### `execute/2`

`execute` is the lowest level hook. It receives the request struct and a function handle for assertions. The default behavior is to call the `call/1` function followed by the assertions:

```
defmodule Test.MyApp do
  use Fugue

  defp execute(request, assertions) do
    request
    |> call()
    |> assertions.()
  end
end
```

### `call/1`

`call` receives the request struct and executes the request. In the case standard `Plug` apps this would look something like:

```elixir
MyApp.call(request, [])
```

When using `Fugue`, you may pass `:plug` and `:plug_opts` to the default `call` implementation:

```elixir
defmodule Test.MyApp do
  use Fugue, plug: MyApp,
             plug_opts: []
end
```

### `init_request/1`

`init_request` is passed the test context and can create the request struct. This is helpful for when something other than `Plug.Conn` is used or the default values for `Plug.Conn` need to be changed.

### `prepare_request/1`

`prepare_request` is called just before calling `execute/2` which allows for any final modifications to the request to be made.
