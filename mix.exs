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
    [{:piper, github: "operable/piper", ref: "b78b673c3d6e611e1151d896d4eda393605ef0f7"},
     {:carrier, github: "operable/carrier", tag: "0.2"},
     {:porcelain, "~> 2.0.1"}]
  end
end
