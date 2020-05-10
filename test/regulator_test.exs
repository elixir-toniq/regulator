defmodule RegulatorTest do
  use ExUnit.Case

  alias Regulator.Limit.Static

  test "can create a new regulator" do
    Regulator.install(:static_limit, {Static, limit: 2})

    assert {:ok, ctx1} = Regulator.ask(:static_limit)
    assert {:ok, ctx2} = Regulator.ask(:static_limit)
    assert :dropped    = Regulator.ask(:static_limit)

    Regulator.success(ctx1)
    assert {:ok, ctx3} = Regulator.ask(:static_limit)
  end
end
