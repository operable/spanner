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
    [{:piper, github: "operable/piper", branch: "kevsmith/emojis"},
     {:carrier, github: "operable/carrier", tag: "0.2"},
     {:porcelain, "~> 2.0.1"}]
  end
end
