defmodule Regulator.PlugTest do
  use ExUnit.Case, async: false
  use Plug.Test

  setup_all do
    Regulator.install(:plug_test, {Regulator.Limit.Static, limit: 2})

    :ok
  end

  test "limits the number of concurrent plug requests" do
    opts = Regulator.Plug.init([regulator: :plug_test])
    conn = conn(:get, "/hello")

    conn = Regulator.Plug.call(conn, opts)
    assert conn.status == nil

    conn = Regulator.Plug.call(conn, opts)
    assert conn.status == nil

    conn = Regulator.Plug.call(conn, opts)
    assert conn.status == 403
    assert conn.resp_body == "Overloaded"
  end

  test "status code and message can be changed" do
    opts = Regulator.Plug.init([regulator: :plug_test, error_code: 500, error_message: "Leave me alone"])
    conn = conn(:get, "/hello")

    conn = Regulator.Plug.call(conn, opts)
    conn = Regulator.Plug.call(conn, opts)

    conn = Regulator.Plug.call(conn, opts)
    assert conn.status == 500
    assert conn.resp_body == "Leave me alone"
  end
end
