defmodule Regulator.Application do
  @moduledoc false
  use Application

  def start(_, _) do
    children = [
      {DynamicSupervisor, name: Regulator.Regulators, strategy: :one_for_one}
    ]

    opts = [strategy: :one_for_one, name: Regulator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
