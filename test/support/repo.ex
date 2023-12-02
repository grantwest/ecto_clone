defmodule EctoClone.Repo do
  use Ecto.Repo,
    otp_app: :ecto_clone,
    adapter: Ecto.Adapters.Postgres
end
