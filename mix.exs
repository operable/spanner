defmodule Spanner.Mixfile do
  use Mix.Project

  def project do
    [app: :spanner,
     version: "0.17.0",
     elixir: "~> 1.3.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger,
                    :yaml_elixir]]
  end

  defp deps do
    [{:piper, github: "operable/piper", tag: "1.0.0-beta.1"},
     {:yaml_elixir, "~> 1.2"},
     {:ex_json_schema, "~> 0.5"}]
  end
end
