defmodule Regulator.LimitCalculator do
  @moduledoc false
  # The limit calculator periodically wakes up, fetches all of the latencies
  # in the buffers and calculates the new concurrency limit based on the specified
  # limit algorithm. The default time window is 1 second. But if the maximum
  # number of events is not present in the buffers than we'll wait for another
  # time window before processing.
  use GenServer

  alias Regulator.Window

  require Logger

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts)
  end

  def init(opts) do
    data = Map.new(opts)

    schedule()

    {:ok, data}
  end

  def handle_info(:calculate, state) do
    entries =
      state.buffers
      |> Enum.flat_map(fn tab ->
        case :ets.lookup(tab, :index) do
          [{:index, index}] ->
            records = :ets.select(tab, ms(index))
            :ets.select_delete(tab, ms(index))
            records

          [] ->
            []
        end
      end)

    window = Enum.reduce(entries, Window.new(), fn entry, window ->
      Window.add(window, entry)
    end)

    Logger.debug("Do some limiting math here...")
    Logger.debug(fn -> "Window: #{inspect window}" end)

    schedule()

    {:noreply, state}
  end

  defp ms(index) do
    # Get integers less than the current index
    [{{:"$1", :"$2"}, [{:andalso, {:is_integer, :"$1"}, {:<, :"$1", index}}], [:"$2"]}]
  end

  defp schedule(timeout \\ 10_000) do
    # next time = min(max(min_time * 2, 1_000), 1_000)
    # If our minimum requests are taking way longer than 1 second than don't try
    # schedule another
    Process.send_after(self(), :calculate, timeout)
  end
end

