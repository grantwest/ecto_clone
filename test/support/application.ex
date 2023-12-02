defmodule EctoClone.Test.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EctoClone.Repo
    ]

    opts = [strategy: :one_for_one, name: EctoClone.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
