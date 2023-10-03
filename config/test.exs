import Config

config :logger, level: :warning

config :ecto_graf, EctoGraf.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DB_HOSTNAME", "localhost"),
  database: "ecto_graf_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support",
  pool_size: 10

config :ecto_graf,
  ecto_repos: [EctoGraf.Repo]

config :ecto_graf, :sandbox, Ecto.Adapters.SQL.Sandbox
