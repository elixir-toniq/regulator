defmodule Regulator do
  @moduledoc """
  Adaptive concurrency limits.
  """
  alias Regulator.Context
  alias Regulator.Regulators
  alias Regulator.LimiterSup
  alias Regulator.Limits
  alias Regulator.Buffer
  alias Regulator.Telemetry

  def install(name, {mod, opts}) do
    opts = %{name: name, limit: {mod, mod.new(opts)}}
    DynamicSupervisor.start_child(Regulators, {LimiterSup, opts})
  end

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

  @doc """
  Determine if we have available concurrency to make another request
  """
  def ask(name) do
    inflight = Limits.add(name)

    if inflight <= Limits.limit(name) do
      {:ok, Context.new(name, inflight)}
    else
      Limits.sub(name)
      :dropped
    end
  end

  def success(context) do
    rtt = System.monotonic_time() - context.start
    Limits.sub(context.regulator)
    Buffer.add_sample(context.regulator, {rtt, context.inflight, false})

    :ok
  end

  def dropped(context) do
    rtt = System.monotonic_time() - context.start
    Limits.sub(context.regulator)
    Buffer.add_sample(context.regulator, {rtt, context.inflight, true})

    :ok
  end

  def ignore(context) do
    Limits.sub(context.regulator)

    :ok
  end
end
