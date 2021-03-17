# Regulator

Regulator provides adaptive concurrency limits around external resources.

```elixir
Regulator.install(:service, {Regulator.Limit.AIMD, [timeout: 500]})

Regulator.ask(:service, fn ->
  Finch.request(:get, "https://keathley.io")
end)
```

## Why do I need this?

If you're used to circuit breakers, you can think of Regulator as an adaptive,
dynamic circuit breaker. Regulator determines if there are errors or potential
for errors by measuring the running system. When it detects errors - more specifically
it detects queueing - it begins to lower the number of concurrent _things_ that
can happen in the system.

For instance, Regulator has determined that it can allow 4 concurrent requests to
a downstream API, and 4 requests are initiated, any further requests will be
rejected immediately.

Rejecting the request allows you, the programmer, to determine what to do if Regulator
is shedding load. here's an example where we will normally serve requests from
a downstream system, but under load shedding, we return a cached value.


```elixir
def fetch(id) do
  case Regulator.ask(:service) do
    {:ok, token} ->
      case api_call(id) do
        {:ok, resp} ->
          :ok = Regulator.ok(token)
          :ok = Cache.put(id, resp)
          {:ok, resp}

        {:error, error} ->
          Regulator.error(token)
          {:error, error}
      end

    :dropped ->
      case Cache.get(id) do
        nil ->
          {:error, :not_found}

        resp ->
          {:ok, resp}
      end
  end)
end
```

## Should I use this

There are additional tests that need to be added and there may be performance
improvements required around concurrency token monitoring. But, this has been
used heavily in production and has supported 10s of thousands of requests per second.
I feel confident in saying that you can use this in production at this point.
