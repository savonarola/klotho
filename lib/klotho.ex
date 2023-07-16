defmodule Klotho do
  @moduledoc """
  A module that provides a interface to Erlang's time functions.

  In production, all functions are proxied to the `:erlang` module directly.

  In tests, the functions are proxied to `Klotho.Mock`, and the time "flow"
  can be controlled by calling `Klotho.Mock` functions.
  """

  if Mix.env() == :test do
    @backend Klotho.Mock
  else
    @backend Klotho.Real
  end

  def monotonic_time(unit) do
    @backend.monotonic_time(unit)
  end

  def monotonic_time() do
    @backend.monotonic_time()
  end

  def send_after(time, pid, message) do
    @backend.send_after(time, pid, message)
  end

  def send_after(time, pid, message, opts) do
    @backend.send_after(time, pid, message, opts)
  end

  def start_timer(time, pid, message) do
    @backend.start_timer(time, pid, message)
  end

  def start_timer(time, pid, message, opts) do
    @backend.start_timer(time, pid, message, opts)
  end

  def read_timer(ref) do
    @backend.read_timer(ref)
  end

  def cancel_timer(ref) do
    @backend.cancel_timer(ref)
  end

  def cancel_timer(ref, opts) do
    @backend.cancel_timer(ref, opts)
  end

  def system_time(unit) do
    @backend.system_time(unit)
  end

  def system_time() do
    @backend.system_time()
  end

  def time_offset(unit) do
    @backend.time_offset(unit)
  end

  def time_offset() do
    @backend.time_offset()
  end
end
