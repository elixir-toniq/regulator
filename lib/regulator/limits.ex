defmodule Regulator.Limits do
  @moduledoc false
  # Module for interacting with the current inflight count and the maximum inflight limit.

  def new(name, initial_limit) do
    _table = :ets.new(:"#{name}-limits", [:named_table, :set, :public, {:write_concurrency, true}])

    :ets.insert(:"#{name}-limits", {:max_inflight, initial_limit})
    :ets.insert(:"#{name}-limits", {:inflight, 0})

    name
  end

  # Add a new inflight request
  def add(name) do
    :ets.update_counter(:"#{name}-limits", :inflight, 1)
  end

  def sub(name) do
    :ets.update_counter(:"#{name}-limits", :inflight, {2, -1, 0, 0}, {:inflight, 0})
  end

  def inflight(name) do
    [{:inflight, count}] = :ets.lookup(:"#{name}-limits", :inflight)
    count
  end

  # Get the current concurrency limit
  def limit(name) do
    [{:max_inflight, limit}] = :ets.lookup(:"#{name}-limits", :max_inflight)
    limit
  end

  def set_limit(name, limit) do
    :ets.insert(:"#{name}-limits", {:max_inflight, limit})
  end
end
