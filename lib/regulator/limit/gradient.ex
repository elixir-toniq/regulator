defmodule Regulator.Limit.Gradient do
  @moduledoc """
  Limiter based on the gradient of change. Based on Netflix's gradient2 algorithm.
  https://github.com/Netflix/concurrency-limits.

  ## Options
  * `:initial_limit` - The initial limit when the regulator is installed (defaults to 20).
  * `:min_limit` - The minimum limit for the regulator (defaults to 5).
  * `:max_limit` - The maximum limit for the regulator (defaults to 200).
  * `:smoothing` - Determines how aggressively the concurrency limit can shrink
    if there is queueing. Numbers should be between 0.0 and 1.0. Higher numbers
    will cause the limit to shrink faster.
  * `:rtt_tolerance` - Specifies how much change in average round trip time will
    be allowed before reducing the concurrency limit. A value of 2.0 would mean
    that a 2x increase in rtt would be acceptable. Default 1.5.
  * `:long_window_count` - Defines the number of sample windows that will be considered in the long term moving average. Setting this value lower will cause the long term window to adjust more aggressively. Default 600.
  """

  @behaviour Regulator.Limit

  alias Regulator.Limit.ExpAvg
  alias Regulator.Window

  defstruct [
    min_limit: 5,
    max_limit: 200,
    smoothing: 0.2,
    rtt_tolerance: 1.5,
    # This LongRTT is an exponential moving average. We use 600 samples here in
    # which roughly works out to 10 minutes of sample time.
    long_rtt: ExpAvg.new(600, 10),
    estimated_limit: 5,
    last_rtt: 0,
  ]

  @impl true
  def new(opts) do
    opts = if opts[:initial_limit] do
      put_in(opts, [:estimated_limit], opts[:initial_limit])
    else
      opts
    end

    struct(__MODULE__, opts)
  end

  @impl true
  def initial(config) do
    config.estimated_limit
  end

  @impl true
  def update(gradient, _current_limit, window) do
    queue_size = 2 # This should be determined dynamically

    case Window.avg_rtt(window) do
      0 ->
        {gradient, gradient.estimated_limit}

      short_rtt ->
        long_rtt = update_long_rtt(gradient.long_rtt, short_rtt)
        gradient = %{gradient | long_rtt: long_rtt}

        # If we don't have enough inflight requests we don't really need to grow the limit
        # So just bail out.
        if window.max_inflight < gradient.estimated_limit / 2 do
          {gradient, gradient.estimated_limit}
        else
          grad = max(0.5, min(1.0, gradient.rtt_tolerance * long_rtt.value / short_rtt))
          new_limit = gradient.estimated_limit * grad + queue_size
          # Calculate the EMA of the estimated limit
          new_limit = gradient.estimated_limit * (1 - gradient.smoothing) + new_limit * gradient.smoothing

          # Clamp the limit values based on the users configuration
          new_limit = max(gradient.min_limit, min(gradient.max_limit, new_limit))
          gradient = %{gradient | estimated_limit: new_limit}

          {gradient, trunc(new_limit)}
        end
    end
  end

  defp update_long_rtt(long_rtt, rtt) do
    long_rtt = ExpAvg.add(long_rtt, rtt)

    # If the long RTT is substantially larger than the short rtt then reduce the
    # long RTT measurement. This can happen when latency returns to normal after
    # a excessive load. Reducing the long RTT without waiting for the exponential
    # smoothing helps bring teh system back to steady state.
    if long_rtt.value / rtt > 2 do
      ExpAvg.update(long_rtt, fn current -> current * 0.95 end)
    else
      long_rtt
    end
  end
end
