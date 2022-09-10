defmodule Regulator.MixProject do
  use Mix.Project

  @version "0.5.0"

  def project do
    [
      app: :regulator,
      version: @version,
      elixir: "~> 1.9",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      description: description(),
      package: package(),
      name: "Regulator",
      source_url: "https://github.com/keathley/regulator",
      docs: docs()
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(:dev), do: ["lib", "test/support/usage.ex"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger],
      mod: {Regulator.Application, []}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:telemetry, "~> 0.4 or ~> 1.0"},
      {:plug, "~> 1.10"},
      {:norm, "~> 0.12"},

      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false},
      {:credo, "~> 1.4", only: [:dev, :test], runtime: false},
      {:ex_doc, "~> 0.0", only: [:dev, :test]},
      {:propcheck, "~> 1.2", only: [:dev, :test]},
    ]
  end

  def description do
    """
    Regulator provides adaptive conconcurrency and congestion control algorithms
    for load shedding.
    """
  end

  def package do
    [
      name: "regulator",
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/keathley/regulator"}
    ]
  end

  def docs do
    [
      source_ref: "v#{@version}",
      source_url: "https://github.com/keathley/regulator",
      main: "Regulator"
    ]
  end
end
