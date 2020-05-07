defmodule Regulator.Limit.AIMD do
  @moduledoc """
  Loss based dynamic limit algorithm. Additively increases the concurrency
  limit when there are no errors and multiplicatively decrements the limit
  when there are errors.
  """
  defstruct [
    min_limit: 20,
    initial_limit: 20,
    max_limit: 200,
    backoff_ratio: 0.9,
    timeout: 5,
  ]

  def update(limit, current_limit, rtt, inflight, was_dropped) do
    current_limit = cond do
      # If we've dropped a request or if the avg rtt is less than the timeout
      # we backoff
      was_dropped || rtt > limit.timeout ->
        # Floors the value and converts to integer
        trunc(current_limit * limit.backoff_ratio)

      # If we're halfway to the current limit go ahead and increase the limit.
      current_limit <= inflight * 2 ->
        current_limit + 1
    end

    # If we're at the max limit reset to 50% of the maximum limit
    current_limit = if limit.max_limit <= current_limit do
      div(current_limit, 2)
    else
      current_limit
    end

    # Return the new limit bounded by the configured min and max
    min(limit.max_limit, max(limit.min_limit, current_limit))
  end
end
