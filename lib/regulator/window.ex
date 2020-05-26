defmodule Regulator.Window do
  @moduledoc false
  # Tracks samples over a window of time (typically 1 second). This window
  # is used to derive new concurrency limits.

  @type t :: %{
    sum: pos_integer(),
    min_rtt: pos_integer(),
    max_inflight: pos_integer(),
    sample_count: pos_integer(),
    did_drop?: boolean(),
  }

  def new do
    %{
      # The total rtt for all requests
      sum: 0,
      # min rtt seen
      min_rtt: nil,

      # Max in-flight requests
      max_inflight: 0,

      sample_count: 0,

      # Did we drop a request in this window?
      did_drop?: false
    }
  end

  def add(window, {rtt, inflight, was_dropped}) do
    window
    |> Map.update!(:sum, & &1 + rtt)
    |> Map.update!(:min_rtt, & (if &1 == nil, do: rtt, else: min(&1, rtt)))
    |> Map.update!(:max_inflight, & max(&1, inflight))
    |> Map.update!(:sample_count, & &1 + 1)
    |> Map.update!(:did_drop?, & &1 || was_dropped)
  end

  def avg_rtt(%{sum: sum, sample_count: sample_count}) do
    if sample_count == 0 do
      0
    else
      # Floor this value so we don't have to deal with floats
      div(sum, sample_count)
    end
  end
end
