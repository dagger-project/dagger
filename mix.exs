defmodule Dagger.MixProject do
  use Mix.Project

  def project do
    [
      app: :dagger,
      version: "0.1.0",
      elixir: "~> 1.14",
      elixirc_paths: elixirc_paths(Mix.env()),
      elixirc_options: elixirc_options(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      test_coverage: test_coverage(),
      aliases: aliases(),
      preferred_cli_env: [cover: :test, coverage: :test]
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:jason, "~> 1.4.0"}
    ]
  end

  defp elixirc_options(:prod), do: [warnings_as_errors: true]
  defp elixirc_options(_), do: []

  defp elixirc_paths(:dev), do: ["lib", "examples"]
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp aliases() do
    [coverage: "test --cover", cover: "coverage"]
  end

  defp test_coverage() do
    [
      summary: [threshold: 80],
      ignore_modules: ignore_for_test()
    ]
  end

  defp ignore_for_test() do
    [
      Dagger.Compiler.Checker,
      Dagger.Compiler.Checkers.NoConditionalsChecker,
      Dagger.CompilerHelpers,
      Dagger.Flow,
      Dagger.GraphNeverFinishesError,
      Dagger.MissingStepError,
      Dagger.StepConfigurationError
    ]
  end
end
