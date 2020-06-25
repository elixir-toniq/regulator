defmodule Regulator.Plug do
  @moduledoc """
  A plug used for regulating the concurrency limit of an endpoint or series of
  endpoints.

  ## Options

  * `:regulator` - Required. The regulator to use for this plug.
  * `:error_code` - The status code to use when the concurrency limit is reached. Defaults to 403.
  * `:error_message` - The message to return when the concurrency limit is reached. Must be a binary. Defaults to "Overloaded".
  """

  import Plug.Conn

  def init(opts) do
    %{
      regulator: Keyword.fetch!(opts, :regulator),
      error_code: Keyword.get(opts, :error_code, 403),
      error_message: Keyword.get(opts, :error_message, "Overloaded")
    }
  end

  def call(conn, opts) do
    case Regulator.ask(opts.regulator) do
      :dropped ->
        conn
        |> send_resp(opts.error_code, opts.error_message)
        |> halt()

      {:ok, ctx} ->
        register_before_send(conn, fn conn ->
          cond do
            conn.status == 401 ->
              Regulator.ignore(ctx)

            conn.status >= 500 ->
              Regulator.error(ctx)

            true ->
              Regulator.ok(ctx)
          end

          conn
        end)
    end
  end
end
