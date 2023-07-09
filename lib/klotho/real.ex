defmodule Klotho.Real do
  def monotonic_time(unit) do
    :erlang.monotonic_time(unit)
  end

  def monotonic_time() do
    :erlang.monotonic_time()
  end

  def send_after(time, pid, message) do
    :erlang.send_after(time, pid, message)
  end

  def start_timer(time, pid, message) do
    :erlang.start_timer(time, pid, message)
  end

  def read_timer(ref) do
    :erlang.read_timer(ref)
  end

  def cancel_timer(ref) do
    :erlang.cancel_timer(ref)
  end
end
