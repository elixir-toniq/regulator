defmodule Regulator.Limit.AIMD do
  @moduledoc """
  Loss based dynamic limit algorithm. Additively increases the concurrency
  limit when there are no errors and multiplicatively decrements the limit
  when there are errors.

  To use this regulator you must specify a "target average latency". Regulator collects
  measurements of your service calls and averages them over a sliding window. If the
  average latency is above the target specified, regulator considers it an error
  and will begin to multiplicatively decrease the concurrency limit. If the avg latency
  is *below* the target **and** over half of the concurrency tokens were utilized
  during the window, then regulator will increase the concurrency limit by a fixed value.
  If less than half of the concurrency tokens were utilized in the window, Regulator
  leaves the concurrency limit as is, since there is no need for additional tokens.

  Finally, if there was any errors that occured during the window, Regulator treats that
  as a backoff situation and will begin to reduce the concurrency limit.

  ## Options
  * `:min_limit` - The minimum concurrency limit (defaults to 5)
  * `:initial_limit` - The initial concurrency limit when the regulator is installed (deafults to 20)
  * `:max_limit` - The maximum concurrency limit (defaults to 200)
  * `:step_increase` - The number of tokens to add when regulator is increasing the concurrency limit (defaults to 10).
  * `:backoff_ratio` - Floating point value for how quickly to reduce the concurrency limit (defaults to 0.9)
  * `:target_avg_latency` - This is the average latency in milliseconds for the system regulator is protecting. If the average latency drifts above this value Regulator considers it an error and backs off. Defaults to 5.
  * `:timeout` - alias for `target_avg_latency`.
  """
  @behaviour Regulator.Limit

  alias Regulator.Window

  defstruct [
    min_limit: 5,
    initial_limit: 20,
    max_limit: 200,
    backoff_ratio: 0.9,
    target_avg_latency: 5,
    step_increase: 10,
  ]

  @impl true
  def new(opts) do
    legacy_timeout = opts[:timeout] || 5
    opts =
      opts
      |> Keyword.new()
      |> Keyword.put_new(:target_avg_latency, legacy_timeout)
    config = struct(__MODULE__, opts)
    %{config | target_avg_latency: System.convert_time_unit(config.target_avg_latency, :millisecond, :native)}
  end

  @impl true
  def initial(config) do
    config.initial_limit
  end

  @impl true
  def update(config, current_limit, window) do
    current_limit = cond do
      # If we've dropped a request or if the avg rtt is greater than the timeout
      # we backoff
      window.did_drop? || Window.avg_rtt(window) > config.target_avg_latency ->
        # Floors the value and converts to integer
        trunc(current_limit * config.backoff_ratio)

      # If we're halfway to the current limit go ahead and increase the limit.
      window.max_inflight * 2 >= current_limit ->
        current_limit + config.step_increase

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
    {config, min(config.max_limit, max(config.min_limit, current_limit))}
  end
end
