defmodule Regulator.Context do
  @moduledoc """
  Provides a context map for when a lock is acquired. This context struct
  must be returned to the regulator once work has been done.
  """
  defstruct [
    regulator: nil,
    start: nil,
    inflight: 0
  ]

  def new(name, inflight) do
    %__MODULE__{
      regulator: name,
      start: System.monotonic_time(),
      inflight: inflight
    }
  end
end
