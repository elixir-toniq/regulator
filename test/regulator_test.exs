defmodule RegulatorTest do
  use ExUnit.Case

  alias Regulator.Limit.Static

  test "can create a new regulator" do
    Regulator.install(:static_limit, {Static, limit: 2})

    result = Regulator.ask(:static_limit, fn ->
      result = Regulator.ask(:static_limit, fn ->
        assert :dropped = Regulator.ask(:static_limit, fn -> nil end)
        {:ok, :dropped}
      end)

      {:ok, result}
    end)

    assert result == :dropped
  end
end
