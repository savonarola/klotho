defmodule Klotho.Real do
  @moduledoc false

  def monotonic_time(unit) do
    :erlang.monotonic_time(unit)
  end

  def monotonic_time() do
    :erlang.monotonic_time()
  end

  def send_after(time, pid, message) do
    :erlang.send_after(time, pid, message)
  end

  def send_after(time, pid, message, opts) do
    :erlang.send_after(time, pid, message, opts)
  end

  def start_timer(time, pid, message) do
    :erlang.start_timer(time, pid, message)
  end

  def start_timer(time, pid, message, opts) do
    :erlang.start_timer(time, pid, message, opts)
  end

  def read_timer(ref) do
    :erlang.read_timer(ref)
  end

  def cancel_timer(ref) do
    :erlang.cancel_timer(ref)
  end

  def cancel_timer(ref, opts) do
    :erlang.cancel_timer(ref, opts)
  end

  def system_time() do
    :erlang.system_time()
  end

  def system_time(unit) do
    :erlang.system_time(unit)
  end

  def time_offset() do
    :erlang.time_offset()
  end

  def time_offset(unit) do
    :erlang.time_offset(unit)
  end
end
