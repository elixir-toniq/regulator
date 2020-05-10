defmodule Regulator.Telemetry do
  @moduledoc """
  Regulator produces multiple telemetry events.

  ## Events

  * `[:regulator, :limit]` - Returns the calculated limit from the
  """

  @doc false
  def start(name, meta, measurements \\ %{}) do
    time = System.monotonic_time()
    measures = Map.put(measurements, :system_time, time)
    :telemetry.execute([:regulator, name, :start], measures, meta)
    time
  end

  def stop(name, start_time, meta, measurements \\ %{}) do
    end_time = System.monotonic_time()
    measurements = Map.merge(measurements, %{duration: end_time - start_time})

    :telemetry.execute(
      [:regulator, name, :stop],
      measurements,
      meta
    )
  end

  @doc false
  def exception(event, start_time, kind, reason, stack, meta \\ %{}, extra_measurements \\ %{}) do
    end_time = System.monotonic_time()
    measurements = Map.merge(extra_measurements, %{duration: end_time - start_time})

    meta =
      meta
      |> Map.put(:kind, kind)
      |> Map.put(:error, reason)
      |> Map.put(:stacktrace, stack)

    :telemetry.execute([:regulator, event, :exception], measurements, meta)
  end

  @doc false
  def event(name, metrics, meta) do
    :telemetry.execute([:regulator, name], metrics, meta)
  end
end
