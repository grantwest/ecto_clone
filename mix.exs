defmodule EctoClone.MixProject do
  use Mix.Project

  @version "0.2.0"
  @description "Leverage Ecto associations to deep clone db records & do other helpful stuff"
  @source_url "https://github.com/grantwest/ecto_clone"

  def project do
    [
      app: :ecto_clone,
      version: @version,
      elixir: "~> 1.13",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      package: package(),
      description: @description,
      aliases: aliases(),
      preferred_cli_env: [
        "test.watch": :test
      ],
      name: "EctoClone",
      docs: docs()
    ]
  end

  def application do
    always = [
      extra_applications: [:logger]
    ]

    case Mix.env() do
      :test -> always ++ [mod: {EctoClone.Test.Application, []}]
      _ -> always
    end
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:ecto, ">= 3.9.0"},
      {:ecto_sql, ">= 3.9.0", only: [:test]},
      {:postgrex, ">= 0.16.0", only: [:test]},
      {:mix_test_watch, "~> 1.0", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.27", only: :dev, runtime: false}
    ]
  end

  defp aliases do
    [
      "ecto.setup": ["ecto.create", "ecto.migrate"],
      "ecto.reset": ["ecto.drop", "ecto.setup"],
      test: ["ecto.create --quiet", "ecto.migrate --quiet", "test"]
    ]
  end

  defp package do
    %{
      licenses: ["0BSD"],
      maintainers: ["Grant West"],
      links: %{"GitHub" => @source_url}
    }
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      source_url: @source_url,
      extras: ["README.md"],
      main: "readme"
    ]
  end
end
