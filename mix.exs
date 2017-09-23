defmodule Spanner.Mixfile do
  use Mix.Project

  def project do
    [app: :spanner,
     version: "1.1.0",
     elixir: "~> 1.5.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     test_coverage: [tool: ExCoveralls],
     preferred_cli_env: ["coveralls": :test,
                         "coveralls.html": :test,
                         "coveralls.travis": :test],
     deps: deps()]
  end

  def application do
    [applications: [:logger,
                    :yaml_elixir]]
  end

  defp deps do
    [{:piper, github: "davejlong/piper", branch: "elixir-upgrade"},
     {:yaml_elixir, "~> 1.3"},
     {:ex_json_schema, "~> 0.5"},

     {:excoveralls, "~> 0.7", only: :test}]
  end
end
