defmodule Klotho.Application do
  @moduledoc false

  use Application

  if Mix.env() == :test do
    @children [{Klotho.Mock, :running}]
  else
    @children []
  end

  @impl true
  def start(_type, _args) do
    opts = [strategy: :one_for_one, name: Klotho.Supervisor]
    Supervisor.start_link(@children, opts)
  end
end
