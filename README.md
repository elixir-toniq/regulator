# Regulator

Regulator provides adaptive concurrency limits around external resources.

```elixir
Regulator.install(:service, {Regulator.Limit.AIMD, [timeout: 500]})

Regulator.ask(:service, fn ->
  {:ok, Finch.request(:get, "https://keathley.io")}
end)
```

## Should I use this

Probably not yet.
