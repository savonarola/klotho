defmodule Klotho.Support.TimeoutCache do
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
