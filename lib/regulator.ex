defmodule Regulator do
  @moduledoc """
  Adaptive concurrency limits.
  """
  alias Regulator.Regulators
  alias Regulator.LimiterSup
  alias Regulator.Limits
  alias Regulator.Buffer
  alias Regulator.Telemetry

  @doc """
  Creates a new regulator.
  """
  def install(name, {mod, opts}) do
    opts = %{name: name, limit: {mod, mod.new(opts)}}
    DynamicSupervisor.start_child(Regulators, {LimiterSup, opts})
  end

  @doc """
  Ask for access to a protected service. If we've reached the concurrency limit
  then `ask` will return a `:dropped` atom without executing the callback. Otherwise
  the callback will be applied. The callback must return tuple with the result
  as the first element and the desired return value as the second. The available
  result atoms are:

  * `:ok` - The call succeeded.
  * `:drop` - The call failed or timed out. This is used as a signal to backoff or otherwise adjust the limit.
  * `:ignore` - The call should not be counted in the concurrency limit. This is typically used to filter out status checks and other low latency RPCs.
  """
  def ask(name, f) do
    inflight = Limits.add(name)
    start = Telemetry.start(:ask, %{regulator: name}, %{inflight: inflight})

    try do
      if inflight <= Limits.limit(name) do
        {result, user_result} = f.()
        rtt                   = System.monotonic_time() - start
        Limits.sub(name)

        case result do
          :ok ->
            Telemetry.stop(:ask, start, %{regulator: name, result: :ok})
            Buffer.add_sample(name, {rtt, inflight, false})
            user_result

          :drop ->
            Telemetry.stop(:ask, start, %{regulator: name, result: :drop})
            Buffer.add_sample(name, {rtt, inflight, true})
            user_result

          :ignore ->
            Telemetry.stop(:ask, start, %{regulator: name, result: :ignore})
            user_result
        end
      else
        Telemetry.stop(:ask, start, %{regulator: name, result: :dropped})
        Limits.sub(name)
        :dropped
      end
    rescue
      error ->
        Telemetry.exception(:ask, start, :error, error, __STACKTRACE__, %{regulator: name})
        reraise error, __STACKTRACE__
    catch
      :exit, reason ->
        Telemetry.exception(:ask, start, :exit, reason, __STACKTRACE__, %{regulator: name})
        exit(reason)
    end
  end
end
