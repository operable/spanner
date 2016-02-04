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
    [{:piper, git: "git@github.com:operable/piper", ref: "888d9df3eeeb16954bf0e68c9083a28baf6c92d5"},
     {:carrier, git: "git@github.com:operable/carrier", ref: "09b83330cf957f247eef760723ac19718b5263a5"},
     {:porcelain, "~> 2.0.1"}]
  end
end
