defmodule Klotho.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {Klotho.Mock, :running}
    ]

    opts = [strategy: :one_for_one, name: Klotho.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
