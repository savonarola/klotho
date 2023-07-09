defmodule Klotho do
  @moduledoc false

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

  def start_timer(time, pid, message) do
    @backend.start_timer(time, pid, message)
  end

  def read_timer(ref) do
    @backend.read_timer(ref)
  end

  def cancel_timer(ref) do
    @backend.cancel_timer(ref)
  end
end
