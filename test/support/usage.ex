defmodule Regulator.Usage do
  @moduledoc false

  def test(opt) do
    case Regulator.ask(:foo) do
      {:ok, token} ->
        cond do
          opt == 1337 ->
            :ok = Regulator.ok(token)

          opt == 420 ->
            :ok = Regulator.error(token)

          true ->
            :ok = Regulator.ignore(token)
        end

      :dropped ->
        nil
    end
  end
end
