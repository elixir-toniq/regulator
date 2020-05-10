defmodule Regulator.LimiterSup do
  @moduledoc false
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts)
  end

  def init(opts) do
    name = opts[:name]
    {mod, limit_opts} = opts[:limit]
    initial_limit = mod.initial(limit_opts)

    buffer = Regulator.Buffer.new(name)
    limits = Regulator.Limits.new(name, initial_limit)

    children = [
      {Regulator.LimitCalculator, buffer: buffer, limits: limits, limit: opts[:limit]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
