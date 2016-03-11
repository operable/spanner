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
    [{:piper, github: "operable/piper", ref: "c0f65733209d985d0a25b9372ba4ecc62ea77f7f"},
     {:carrier, github: "operable/carrier", ref: "41a868cc01d1a1625354c7b56b76f6a814bbfae4"},

     # For yaml parsing. yaml_elixir is a wrapper around yamerl which is a native erlang lib.
     {:yaml_elixir, "~> 1.0.0"},
     {:yamerl, github: "yakaz/yamerl"},

     {:porcelain, "~> 2.0.1"}]
  end
end
