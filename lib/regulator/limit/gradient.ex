defmodule Regulator.Limit.Gradient do
  @moduledoc """
  Limiter based on the gradient of change.
  """

  @behaviour Regulator.Limit

  alias Regulator.Limit.ExpAvg
  alias Regulator.Window

  defstruct [
    initial_limit: 20,
    min_limit: 20,
    max_limit: 200,
    smoothing: 0.2,
    rtt_tolerance: 1.5,
    long_rtt: ExpAvg.new(100, 10),
    estimated_limit: 20,
    last_rtt: 0,
  ]

  @impl true
  def new(opts) do
    struct(__MODULE__, opts)
  end

  @impl true
  def initial(config) do
    config.initial_limit
  end

  @impl true
  def update(gradient, _current_limit, window) do
    queue_size = 4 # This should be determined dynamically

    short_rtt = last_rtt = Window.avg_rtt(window)
    long_rtt = update_long_rtt(gradient.long_rtt, last_rtt)
    gradient = %{gradient | last_rtt: last_rtt, long_rtt: long_rtt}

    # Bail out if we're halfway to the estimated limit
    if (window.max_inflight < gradient.estimated_limit / 2) do
      {gradient, gradient.estimated_limit}
    else
      IO.puts "Updating limit"
      grad = max(0.5, min(1.0, gradient.rtt_tolerance * long_rtt.value / short_rtt))
      new_limit = gradient.estimated_limit * grad + queue_size
      # Calculate the EMA of the estimated limit
      new_limit = gradient.estimated_limit * (1 - gradient.smoothing) + new_limit * gradient.smoothing

      # Clamp the limit values based on the users configuration
      new_limit = max(gradient.min_limit, min(gradient.max_limit, new_limit))
      new_limit = trunc(new_limit)
      gradient = %{gradient | estimated_limit: new_limit}

      {gradient, new_limit}
    end
  end

  defp update_long_rtt(long_rtt, rtt) do
    long_rtt = ExpAvg.add(long_rtt, rtt)

    # If the long RTT is substantially larger than the short rtt then reduce the
    # long RTT measurement. This can happen when latency returns to normal after
    # a excessive load. Reducing the long RTT without waiting for the exponential
    # smoothing helps bring teh system back to steady state.
    if (long_rtt.value / rtt > 2) do
      ExpAvg.update(long_rtt, fn current -> current * 0.95 end)
    else
      long_rtt
    end
  end
end
