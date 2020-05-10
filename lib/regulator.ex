defmodule Regulator do
  @moduledoc """
  Adaptive concurrency limits.
  """
  alias Regulator.Context
  alias Regulator.Regulators
  alias Regulator.LimiterSup
  alias Regulator.Limits
  alias Regulator.Buffer

  def install(name, limit) do
    opts = %{name: name, limit: limit}
    DynamicSupervisor.start_child(Regulators, {LimiterSup, opts})
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
