defmodule RegulatorTest do
  use ExUnit.Case
  alias Regulator.Limit.Static

  @reg :static_limit

  setup do
    Regulator.install(@reg, {Static, limit: 2})

    on_exit fn ->
      Regulator.uninstall(@reg)
    end

    :ok
  end

  test "can install and uninstall regulators" do
    result = Regulator.ask(@reg, fn ->
      result = Regulator.ask(@reg, fn ->
        assert :dropped = Regulator.ask(@reg, fn -> nil end)
        {:ok, :dropped}
      end)

      {:ok, result}
    end)

    assert result == :dropped
    assert Regulator.uninstall(@reg) == :ok
  end

  test "crashing processes are cleaned up" do
    Process.flag(:trap_exit, true)

    spawn_link(fn ->
      {:ok, _ctx} = Regulator.ask(@reg)
      throw :exit
    end)

    assert_receive {:EXIT, _, _}
    eventually(fn ->
      assert Regulator.Limits.inflight(@reg) == 0
    end)
  end

  test "callbacks that raise exceptions are re-thrown" do
    assert_raise ArgumentError, fn ->
      Regulator.ask(@reg, fn -> raise ArgumentError, "bang" end)
    end

    assert Regulator.Limits.inflight(@reg) == 0
  end

  test "callbacks that throw are re-thrown" do
    assert catch_throw(Regulator.ask(@reg, fn -> throw :exit end))

    assert Regulator.Limits.inflight(@reg) == 0
  end

  defp eventually(f, retries \\ 0) do
    if retries > 10 do
      false
    else
      if f.() do
        true
      else
        :timer.sleep(100)
        eventually(f, retries + 1)
      end
    end
  rescue
    err ->
      if retries == 10 do
        reraise err, __STACKTRACE__
      else
        :timer.sleep(200)
        eventually(f, retries + 1)
      end
  end
end
