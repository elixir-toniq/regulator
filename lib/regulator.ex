defmodule Regulator do
  @moduledoc """
  Adaptive concurrency limits.
  """
  alias Regulator.Regulators
  alias Regulator.LimiterSup
  alias Regulator.Limits
  alias Regulator.Buffer
  alias Regulator.Telemetry
  alias Regulator.Monitor

  @doc """
  Creates a new regulator.
  """
  def install(name, {mod, opts}) do
    opts = %{name: name, limit: {mod, mod.new(opts)}}
    DynamicSupervisor.start_child(Regulators, {LimiterSup, opts})
  end

  @doc """
  Removes a regulator.
  """
  def uninstall(name) do
    # Find the limit supervisor and terminate it. This will also clean up the
    # ets tables that we've created since they are created by the supervisor
    # process. If the process is not found then we assume its already been
    # killed.
    case Process.whereis(name) do
      nil ->
        :ok

      pid ->
        DynamicSupervisor.terminate_child(Regulators, pid)
    end
  end

  @doc """
  Ask for access to a protected service. If we've reached the concurrency limit
  then `ask` will return a `:dropped` atom without executing the callback. Otherwise
  the callback will be applied. The callback must return tuple with the result
  as the first element and the desired return value as the second. The available
  result atoms are:

  * `:ok` - The call succeeded.
  * `:error` - The call failed or timed out. This is used as a signal to backoff or otherwise adjust the limit.
  * `:ignore` - The call should not be counted in the concurrency limit. This is typically used to filter out status checks and other low latency RPCs.
  """
  def ask(name, f) do
    with {:ok, ctx} <- ask(name) do
      case safe_execute(ctx, f) do
        {:ok, result} ->
          ok(ctx)
          result

        {:error, result} ->
          error(ctx)
          result

        {:ignore, result} ->
          ignore(ctx)
          result
      end
    end
  end

  @doc """
  Ask for access to a protected service. Instead of executing a callback this
  function returns a `dropped` atom or a context. It is the callers responsibility
  to check the context map back in to the regulator using one of the corresponding
  functions. Care must be taken to avoid leaking these contexts. Otherwise the
  regulator will not be able to adjust the inflight count which will eventually
  deadlock the regulator.
  """
  def ask(name) do
    :ok = Monitor.monitor_me(name)
    inflight = Limits.add(name)
    start = Telemetry.start(:ask, %{regulator: name}, %{inflight: inflight})

    if inflight <= Limits.limit(name) do
      {:ok, %{start: start, name: name, inflight: inflight}}
    else
      Limits.sub(name)
      Monitor.demonitor_me(name)
      Telemetry.stop(:ask, start, %{regulator: name, result: :dropped})
      :dropped
    end
  end

  @doc """
  Checks in a context and marks it as "ok".
  """
  def ok(ctx) do
    rtt = System.monotonic_time() - ctx.start
    Telemetry.stop(:ask, ctx.start, %{regulator: ctx.name, result: :ok})
    Buffer.add_sample(ctx.name, {rtt, ctx.inflight, false})
    Limits.sub(ctx.name)
    Monitor.demonitor_me(ctx.name)

    :ok
  end

  @doc """
  Checks in a context and marks it as an error.
  """
  def error(ctx) do
    rtt = System.monotonic_time() - ctx.start
    Telemetry.stop(:ask, ctx.start, %{regulator: ctx.name, result: :drop})
    Buffer.add_sample(ctx.name, {rtt, ctx.inflight, true})
    Limits.sub(ctx.name)
    Monitor.demonitor_me(ctx.name)

    :ok
  end

  @doc """
  Checks in a context and ignores the result.
  """
  def ignore(ctx) do
    Telemetry.stop(:ask, ctx.start, %{regulator: ctx.name, result: :ignore})
    Limits.sub(ctx.name)
    Monitor.demonitor_me(ctx.name)

    :ok
  end

  defp safe_execute(ctx, f) do
    f.()
  rescue
    error ->
      Limits.sub(ctx.name)
      Monitor.demonitor_me(ctx.name)
      Telemetry.exception(:ask, ctx.start, :error, error, __STACKTRACE__, %{regulator: ctx.name})
      reraise error, __STACKTRACE__
  catch
    kind, reason ->
      Limits.sub(ctx.name)
      Monitor.demonitor_me(ctx.name)
      Telemetry.exception(:ask, ctx.start, kind, reason, __STACKTRACE__, %{regulator: ctx.name})
      :erlang.raise(kind, reason, __STACKTRACE__)
  end
end
