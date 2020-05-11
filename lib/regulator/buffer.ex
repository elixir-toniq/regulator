defmodule Regulator.Buffer do
  @moduledoc false
  # The buffer is designed to efficiently collect statistics from clients
  # It stores each sample in an ets table using the processes currect scheduler
  # id. This helps reduce contention on each ets table since, in theory, only one process should be writing to a table at a time.
  # When we calculate new limits we flush the buffer of all the samples. This is
  # more expensive but is acceptable for the limit calculator.

  defstruct tabs: []

  # Builds a bunch of ets tables, 1 per scheduler and returns them in a struct
  def new(name) do
    # 1 index erlang ftw
    tabs = for s <- 1..System.schedulers() do
      :ets.new(:"#{name}-#{s}", [:named_table, :set, :public, {:write_concurrency, true}])
    end

    %__MODULE__{tabs: tabs}
  end

  def add_sample(name, sample) do
    buffer = :"#{name}-#{:erlang.system_info(:scheduler_id)}"
    index = :ets.update_counter(buffer, :index, 1, {:index, 0})
    :ets.insert(buffer, {index, sample})
  end

  # Returns the latest messages and then deletes them from the buffer
  def flush_latest(buffer) do
    Enum.flat_map(buffer.tabs, fn tab ->
      case :ets.lookup(tab, :index) do
        [{:index, index}] ->
          records = :ets.select(tab, select_spec(index))
          :ets.select_delete(tab, delete_spec(index))
          IO.inspect(:ets.tab2list(tab), label: "Table")
          records

        [] ->
          []
      end
    end)
  end

  defp delete_spec(index) do
    match_spec(index, true)
  end

  def select_spec(index) do
    # If we're selecting stuff we need to get the second element
    match_spec(index, :"$2")
  end

  defp match_spec(index, item) do
    # Get integers less than the current index
    [{{:"$1", :"$2"}, [{:andalso, {:is_integer, :"$1"}, {:"=<", :"$1", index}}], [item]}]
  end
end
