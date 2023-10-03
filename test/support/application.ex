defmodule EctoGraf.Test.Application do
  use Application

  @impl true
  def start(_type, _args) do
    children = [
      EctoGraf.Repo
    ]

    opts = [strategy: :one_for_one, name: EctoGraf.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
