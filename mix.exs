defmodule Spanner.Mixfile do
  use Mix.Project

  def project do
    [app: :spanner,
     version: "0.0.1",
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
    [{:piper, git: "git@github.com:operable/piper", ref: "acfb2150a25004a5ab2a80e7a5bfd418f35ea532"},
     {:carrier, git: "git@github.com:operable/carrier", ref: "4cb2e0981a8c548551702cba6a1453a9f5d15c08"},
     {:porcelain, "~> 2.0.1"}]
  end
end
