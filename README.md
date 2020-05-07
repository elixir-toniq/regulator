# Regulator

Regulator provides adaptive concurrency limits around external resources.

```elixir
def call_a_service do
  Regulator.acquire(:service, fn
    :ok -> Finch.get("https://keathley.io")
    :dropped -> get_cached_content()
  end)

  Regulator.acquire(:service, fn ->
    Finch.get("https://keathley.io")
  end)
end
```
