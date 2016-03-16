defmodule Spanner.Mixfile do
  use Mix.Project

  def project do
    [app: :spanner,
     version: "0.2.0",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger,
                    :yaml_elixir,
                    :porcelain]]
  end

  defp deps do
    [{:piper, github: "operable/piper", ref: "1eb0069bbdc17fdf0312f9f7b1be6224f16e3e70"},
     {:carrier, github: "operable/carrier", ref: "b62433b3c8f2c97d9720675fd6f44cb1bb2808f3"},

     # For yaml parsing. yaml_elixir is a wrapper around yamerl which is a native erlang lib.
     {:yaml_elixir, "~> 1.0.0"},
     {:yamerl, github: "yakaz/yamerl"},

     {:ex_json_schema, "~> 0.3.1"},
     {:porcelain, "~> 2.0.1"}]
  end
end
