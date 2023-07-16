# `Klotho` usage

## General cosiderations

Testing code that deals with time, timeouts, and timers is hard. The main reason is that
getting time and setting timers is often not treated as a public contract, but it actually is.

Often, to test such code, one provides custom significantly reduced timeouts and uses `:timer.sleep/1`.
This approach has several drawbacks:
* it makes the tests slow
* if we use lagre timeouts, it makes the tests even slower
* if we use small timeouts, it makes the tests flaky

One of the approaches to testing without sleeps is injecting time-related functions directly,
thus making the contract explicitly public. However, this makes the code much more
complex and harder to read.

`Klotho` takes a different approach. It injects timer-based functions globally.
With `Klotho` you do not use time-related functions directly, but instead, you use `Klotho` functions that wrap the original ones in production code.

In tests, these functions are replaced with a mock implementation that allows controlling time "flow".
See `Klotho.Mock` for details.

## Example

Assume we have a module implementing a simple "timeout map" functionality. It allows setting
a timeout for a key and records are automatically removed from the map when the timeout expires.


A possible (and a bit naive) implementation could look like this:

```elixir
defmodule TimeoutCache do
  @moduledoc false

  use GenServer

  # API

  def start_link() do
    GenServer.start_link(__MODULE__, [])
  end

  def set(pid, key, value, timeout) do
    GenServer.call(pid, {:set, key, value, timeout})
  end

  def get(pid, key) do
    GenServer.call(pid, {:get, key})
  end

  # gen_server

  def init([]) do
    {:ok, %{}}
  end

  def handle_call({:set, key, value, timeout}, _from, state) do
    new_st =
      state
      |> maybe_delete(key)
      |> put_new(key, value, timeout)

    {:reply, :ok, new_st}
  end

  def handle_call({:get, key}, _from, state) do
    {:reply, get_value(state, key), state}
  end

  def handle_info({:timeout, ref, key}, state) do
    new_st = maybe_delete_timeout(state, key, ref)
    {:noreply, new_st}
  end

  # private

  defp maybe_delete(state, key) do
    case state do
      %{^key => {_value, ref}} ->
        :erlang.cancel_timer(ref)
        Map.delete(state, key)

      _ ->
        state
    end
  end

  defp put_new(state, key, value, timeout) do
    ref = :erlang.start_timer(timeout, self(), key)
    Map.put(state, key, {value, ref})
  end

  defp maybe_delete_timeout(state, key, ref) do
    case state do
      %{^key => {_value, ^ref}} ->
        Map.delete(state, key)

      _ ->
        state
    end
  end

  defp get_value(state, key) do
    case state do
      %{^key => {value, _ref}} ->
        {:ok, value}

      _ ->
        :not_found
    end
  end
end
```

How do we test that keys are actually removed from the map after the timeout expires?
A possible test suite could look like this:

```elixir
defmodule TimeoutCacheTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = TimeoutCache.start_link()
    {:ok, pid: pid}
  end

  test "set and get", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar, 100)
    assert {:ok, :bar} == TimeoutCache.get(pid, :foo)
  end

  test "get after timeout", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar, 100)
    :timer.sleep(200)
    assert :not_found == TimeoutCache.get(pid, :foo)
  end

  test "renew lifetime", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar1, 100)
    :timer.sleep(50)
    TimeoutCache.set(pid, :foo, :bar2, 100)
    :timer.sleep(70)
    assert {:ok, :bar2} == TimeoutCache.get(pid, :foo)
  end
end
```

This test suite is slow and flaky. It is slow because of `:timer.sleep/1` calls.
Also, if the test machine is under heavy load, the timeouts may expire later than expected, thus making the tests flaky.
On the other hand, if we increase the timeouts, the tests will become even slower.

With `Klotho` we may rewrite the implementation as follows:

```elixir
defmodule TimeoutCache do
  ...

  defp maybe_delete(state, key) do
    case state do
      %{^key => {_value, ref}} ->
        Klotho.cancel_timer(ref)
        Map.delete(state, key)

      _ ->
        state
    end
  end

  defp put_new(state, key, value, timeout) do
    ref = Klotho.start_timer(timeout, self(), key)
    Map.put(state, key, {value, ref})
  end

  ...
end
```

We just replaced `:erlang.cancel_timer/1` with `Klotho.cancel_timer/1` and `:erlang.start_timer/3`
with `Klotho.start_timer/3`. See [`timeout_cache.erl`](./test/support/timeout_cache.ex).
Now we can rewrite the test suite as follows:

```elixir
defmodule TimeoutCacheTest do
  use ExUnit.Case

  setup do
    {:ok, pid} = TimeoutCache.start_link()
    Klotho.Mock.reset()
    Klotho.Mock.freeze()
    {:ok, pid: pid}
  end

  test "set and get", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar, 1000)
    assert {:ok, :bar} == TimeoutCache.get(pid, :foo)
  end

  test "get after timeout", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar, 1000)
    ## Timers whose time has passed are triggered in the end of warp
    Klotho.Mock.warp_by(2000)
    assert :not_found == TimeoutCache.get(pid, :foo)
  end

  test "renew lifetime", %{pid: pid} do
    TimeoutCache.set(pid, :foo, :bar1, 1000)
    Klotho.Mock.warp_by(500)
    TimeoutCache.set(pid, :foo, :bar2, 1000)
    Klotho.Mock.warp_by(700)
    assert {:ok, :bar2} == TimeoutCache.get(pid, :foo)
  end
end
```

We may use arbitrary timeouts in tests, just warping the time by the required amount. The code does not
use sleeps and runs fast. Also, the tests are not flaky anymore.

See the difference in the test execution time:

```
$ mix test test/klotho_timeout_cache_test.exs --trace

Klotho.TimeoutCacheTest.Klotho [test/klotho_timeout_cache_test.exs]
  * test set and get (1.7ms) [L#44]
  * test renew lifetime (0.05ms) [L#55]
  * test get after timeout (0.07ms) [L#49]

Klotho.TimeoutCacheTest.Timer [test/klotho_timeout_cache_test.exs]
  * test set and get (0.05ms) [L#12]
  * test renew lifetime (121.8ms) [L#23]
  * test get after timeout (200.9ms) [L#17]

Finished in 0.3 seconds (0.00s async, 0.3s sync)
6 tests, 0 failures
```

## Limitations

`Klotho` does not intend to be suitable for any case and provide beam-wide time injection. It is
designed to be used in a wide but still limited scope of cases when the code deals with some
medium-intensive self-contained time-related logic.

* See `Klotho` for the full list of supported functions.
* The library may not be suitable for testing logic with some high-frequency events or events with
an order of millisecond latency because the time is managed by a `GenServer` process.
* The library may not work well if code actively uses other modules with their own and
intensive time-related logic.
