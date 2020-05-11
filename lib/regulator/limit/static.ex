defmodule Regulator.Limit.Static do
  @moduledoc """
  Fixed limit

  ## Options
  * `:limit` - Statically defined limit
  """
  @behaviour Regulator.Limit

  @impl true
  def new(opts), do: Map.new(opts)

  @impl true
  def initial(opts) do
    opts.limit
  end

  @impl true
  def update(_current_limit, _window, opts) do
    opts.limit
  end
end
