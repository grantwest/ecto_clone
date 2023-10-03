defmodule EctoGraf.Repo do
  use Ecto.Repo,
    otp_app: :ecto_graf,
    adapter: Ecto.Adapters.Postgres
end
