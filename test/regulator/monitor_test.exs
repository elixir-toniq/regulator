defmodule Regulator.MonitorTest do
  use ExUnit.Case, async: false

  test "monitoring and demonitoring processes" do
    pid = self()

    Regulator.Monitor.start_link(name: :test_mon)

    assert :ok = Regulator.Monitor.monitor_me(:test_mon)
    assert Regulator.Monitor.monitored_pids(:test_mon) == [pid]
    assert :ok = Regulator.Monitor.demonitor_me(:test_mon)
    assert Regulator.Monitor.monitored_pids(:test_mon) == []
  end
end
