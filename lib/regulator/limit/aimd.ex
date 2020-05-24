defmodule Regulator.Limit.AIMD do
  @moduledoc """
  Loss based dynamic limit algorithm. Additively increases the concurrency
  limit when there are no errors and multiplicatively decrements the limit
  when there are errors.

  ## Options
  """
  @behaviour Regulator.Limit

  alias Regulator.Window

  defstruct [
    min_limit: 20,
    initial_limit: 20,
    max_limit: 200,
    backoff_ratio: 0.9,
    timeout: 5,
  ]

  def new(opts) do
    config = struct(__MODULE__, opts)
    %{config | timeout: System.convert_time_unit(config.timeout, :millisecond, :native)}
  end

  def initial(config) do
    config.initial_limit
  end

  def update(current_limit, window, config) do #limit, current_limit, rtt, inflight, was_dropped) do
    current_limit = cond do
      # If we've dropped a request or if the avg rtt is greater than the timeout
      # we backoff
      window.did_drop? || Window.avg_rtt(window) > config.timeout ->
        IO.puts "BACKING OFF>>>>>>>>>>>>>>>>>>>>>>>>>>>>>"
        # Floors the value and converts to integer
        trunc(current_limit * config.backoff_ratio)

      # If we're halfway to the current limit go ahead and increase the limit.
      window.max_inflight * 2 >= current_limit ->
        current_limit + 10

      true ->
        current_limit
    end

    # If we're at the max limit reset to 50% of the maximum limit
    current_limit = if config.max_limit <= current_limit do
      div(current_limit, 2)
    else
      current_limit
    end

    # Return the new limit bounded by the configured min and max
    min(config.max_limit, max(config.min_limit, current_limit))
  end
end
