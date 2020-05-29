defmodule Regulator.LimiterSup do
  @moduledoc false
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, opts, name: opts[:name])
  end

  def init(opts) do
    name = opts[:name]
    {mod, limit_opts} = opts[:limit]
    initial_limit = mod.initial(limit_opts)

    buffer = Regulator.Buffer.new(name)
    limits = Regulator.Limits.new(name, initial_limit)

    calculator_config = %{
      name: name,
      buffer: buffer,
      limits: limits,
      limit: opts[:limit]
    }

    children = [
      {Regulator.Monitor, name: name},
      {Regulator.LimitCalculator, calculator_config},
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
