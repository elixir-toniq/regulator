defmodule Regulator.Limit.ExpAvg do
  @moduledoc false
  # Models an exponential, average.

  def new(window, warmup_window) do
    %{
      value: 0.0,
      sum: 0.0,
      window: window,
      warmup_window: warmup_window,
      count: 0,
    }
  end

  def add(measure, sample) do
    # If we have fewer samples than the warmup window we update the count,
    # update the running sum, and get an average value. Otherwise
    # we calculate the exponential moving average using a smoothing factor of 2.
    # EMA => (today * (smoothing / (1 + count))) + (yesterday * (1 - (smoothing / (1 + count))))
    if measure.count < measure.warmup_window do
      measure =
        measure
        |> update_in([:count], & &1+1)
        |> update_in([:sum], & &1 + sample)

      %{measure | value: measure.sum / measure.count}
    else
      factor = 2.0 / (1 + measure.window)
      new_value = (sample * factor) + (measure.value * (1-factor))
      %{measure | value: new_value}
    end
  end

  def update(measure, f) do
    new_value = f.(measure.value)
    %{measure | value: new_value}
  end
end
