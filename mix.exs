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
                    :porcelain]]
  end

  defp deps do
    [{:piper, github: "operable/piper", ref: "c0f65733209d985d0a25b9372ba4ecc62ea77f7f"},
     {:carrier, github: "operable/carrier", tag: "0.2"},
     {:porcelain, "~> 2.0.1"}]
  end
end
