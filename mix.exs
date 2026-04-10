defmodule Prism.MixProject do
  use Mix.Project

  def project do
    [
      app: :prism,
      version: "0.1.0",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      aliases: aliases()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    mod =
      if Mix.env() == :test do
        {Prism.TestApplication, []}
      else
        {Prism, []}
      end

    [
      extra_applications: [:logger, :crypto],
      mod: mod
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ecto_sql, "~> 3.0"},
      {:postgrex, "~> 0.20"},
      {:redix, "~> 1.1"},
      {:castore, "~> 1.0"},
      {:protobuf, "~> 0.14.0"},
      {:websockex, "~> 0.4.3"},
      {:jason, "~> 1.4"},
      {:telemetry, "~> 1.2"},
      {:credo, "~> 1.7", only: [:dev, :test], runtime: false},
      {:dialyxir, "~> 1.4", only: [:dev], runtime: false},
      {:benchee, "~> 1.3", only: [:dev]}
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
    ]
  end

  defp aliases do
    [
      quality: ["format --check-formatted", "credo --strict"],
      ci: ["format --check-formatted", "compile --warnings-as-errors", "test", "credo --strict"]
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]
end
