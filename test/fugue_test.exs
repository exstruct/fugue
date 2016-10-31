defmodule FugueTest do
  use Fugue, plug: FugueSubject

  test "second" do
    assert 1 + 1 == 2
  end

  test "third", context do
    assert context
  end

  test "foo" do
    request()
  after conn ->
    conn
    |> assert_status(200)
  end

  test "bar" do
    method = :post
    path = "/"

    request do
      host "foo.example.com"
      method method
      path path
      header "foo", "bar"
      header [baz: "bang"]
    end
  after conn ->
    conn
    |> assert_status(200)
    |> refute_error_status()
    |> assert_body("Hello, World!")
    |> refute_body("Foo")
    |> assert_body_contains("Hello")
    |> refute_body_contains("Bar")
    |> assert_body_contains(~r/World!$/)
    |> assert_transition("/foo")
    |> refute_transition("/bar")
    |> assert_transition("http://foo.example.com/foo")
  end

  test "assert_term_match" do
    actual = %{"foo" => "\"bar\"", "baz" => 123}

    actual
    |> assert_term_match(%{
      "foo" => bar = inspect("bar"),
      "baz" => _
    })

    assert bar == "\"bar\""
  end

  test "other assert_term_match" do
    title = "Hello, world"
    map = %{"title" => title}

    map
    |> assert_term_match(%{"title" => ^title})
  end

  test "wildcard assert_term_match" do
    map = %{"title" => "foo"}

    map
    |> assert_term_match(%{"title" => _})
  end

  test "bin concat assert_term_match" do
    map = %{"title" => "hello, world"}

    map
    |> assert_term_match(%{"title" => "hello, " <> name})

    assert name == "world"
  end

  test "refute_term_match" do
    actual = %{"foo" => "\"bar\"", "baz" => 123}

    actual
    |> refute_term_match(%{
      "foo" => inspect("foo"),
      "baz" => _
    })
  end

  test "assert_json" do
    request do
      path "/json"
    end
  after conn ->
    conn
    |> assert_status(200)
    |> assert_json(%{"hello" => "worl" <> _})
  end
end
