defmodule Regulator.Limit do
  @moduledoc """
  Provides a behaviour for defining new limit algorithms
  """

  @callback initial(term()) :: pos_integer()
  @callback update(Regulator.Window.t(), term()) :: pos_integer()
end
