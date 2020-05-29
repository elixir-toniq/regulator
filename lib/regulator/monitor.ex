defmodule Regulator.Monitor do
  @moduledoc false
  use GenServer

  alias Regulator.Limits

  def start_link(opts) do
    # TODO - make this not suck later
    name = opts[:name]
    GenServer.start_link(__MODULE__, opts, name: :"#{name}-monitor")
  end

  def monitor_me(name) do
    GenServer.call(:"#{name}-monitor", :monitor)
  end

  def demonitor_me(name) do
    GenServer.call(:"#{name}-monitor", :monitor)
  end

  def init(opts) do
    data = %{
      name: opts[:name],
      refs: %{},
    }
    {:ok, data}
  end

  def handle_call(:monitor, {pid, _}, state) do
    ref = Process.monitor(pid)
    state = put_in(state, [:refs, pid], ref)
    {:reply, :ok, state}
  end

  def handle_call(:demonitor, {pid, _}, state) do
    {ref, refs} = Map.pop(state.refs, pid)
    Process.demonitor(ref)

    {:reply, :ok, %{state | refs: refs}}
  end

  def handle_info({:DOWN, _ref, :process, pid, _reason}, state) do
    refs = Map.delete(state.refs, pid)
    Limits.sub(state.name)
    {:noreply, %{state | refs: refs}}
  end
end
