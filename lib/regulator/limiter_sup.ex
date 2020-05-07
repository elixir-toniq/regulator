defmodule Regulator.LimiterSup do
  @moduledoc false
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    name = opts[:name]

    # 1 index erlang ftw
    buffers = for s <- 1..System.schedulers() do
      :ets.new(:"#{name}-#{s}", [:named_table, :set, :public, {:write_concurrency, true}])
    end

    limits = :ets.new(:"#{name}-limits", [:named_table, :set, :public, {:write_concurrency, true}])
    # TODO - Store the initial limit at this point
    :ets.insert(:"#{name}-limits", {:max_inflight, 10})
    :ets.insert(:"#{name}-limits", {:inflight, 0})

    children = [
      {Regulator.LimitCalculator, buffers: buffers, limits: limits, limit: opts[:limit]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
