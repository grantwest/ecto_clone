import Config

config :logger, level: :warning

config :ecto_clone, EctoClone.Repo,
  username: "postgres",
  password: "postgres",
  hostname: System.get_env("DB_HOSTNAME", "localhost"),
  database: "ecto_clone_test#{System.get_env("MIX_TEST_PARTITION")}",
  pool: Ecto.Adapters.SQL.Sandbox,
  priv: "test/support",
  pool_size: 10

config :ecto_clone,
  ecto_repos: [EctoClone.Repo]

config :ecto_clone, :sandbox, Ecto.Adapters.SQL.Sandbox
