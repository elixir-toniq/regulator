defmodule RegulatorTest do
  use ExUnit.Case

  test "can create a new regulator" do
    Regulator.install(:test, %Regulator.Limit.AIMD{})
    # assert Regulator.hello() == :world
  end
end
