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
end
