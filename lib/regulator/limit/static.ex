defmodule Regulator.Limit.Static do
  @moduledoc """
  Fixed limit

  ## Options
  * `:limit` - Statically defined limit
  """
  @behaviour Regulator.Limit

  @impl true
  def initial(opts) do
    Keyword.fetch!(opts, :limit)
  end

  @impl true
  def update(_window, opts) do
    Keyword.fetch!(opts, :limit)
  end
end
