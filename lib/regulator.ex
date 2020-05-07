defmodule Regulator do
  @moduledoc """
  Adaptive concurrency limits.
  """
  alias Regulator.Context
  alias Regulator.Regulators
  alias Regulator.LimiterSup

  def install(name, limit) do
    opts = %{name: name, limit: limit}
    DynamicSupervisor.start_child(Regulators, {LimiterSup, opts})
  end

  @doc """
  Determine if we have available concurrency to make another request
  """
  def ask(name) do
    # TODO - Build functions for these names
    [{:max_inflight, limit}]    = :ets.lookup(:"#{name}-limits", :max_inflight)
    inflight = :ets.update_counter(:"#{name}-limits", :inflight, {2, 1, limit, limit}, {:inflight, 0})

    # If we have fewer inflight requests than the limit let it through
    if inflight < limit do
      {:ok, Context.new(name, inflight)}
    else
      :dropped
    end
  end

  def success(context) do
    :ets.update_counter(:"#{context.regulator}-limits", :inflight, {2, -1, 0, 0}, {:inflight, 0})
    buffer = :"#{context.regulator}-#{:erlang.system_info(:scheduler_id)}"
    stop = System.monotonic_time()
    rtt = stop - context.start
    index = :ets.update_counter(buffer, :index, 1, {:index, 0})
    :ets.insert(buffer, {index, {rtt, context.inflight, false}})

    :ok
  end

  def dropped(context) do
    :ets.update_counter(:"#{context.regulator}-limits", :inflight, {2, -1, 0, 0}, {:inflight, 0})
    buffer = :"#{context.regulator}-#{:erlang.system_info(:scheduler_id)}"
    stop = System.monotonic_time()
    rtt = stop - context.start
    index = :ets.update_counter(buffer, :index, 1, {:index, 0})
    :ets.insert(buffer, {index, {rtt, context.inflight, true}})

    :ok
  end

  def ignore(context) do
    :ets.update_counter(:"#{context.regulator}-limits", :inflight, {2, -1, 0, 0}, {:inflight, 0})

    :ok
  end
end
