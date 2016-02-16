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
    [{:piper, git: "git@github.com:operable/piper", ref: "3915f008654230349d7b828c0f30f782c90d55f8"},
     {:carrier, git: "git@github.com:operable/carrier", ref: "385f2d6f724dfd5fea0421e010b9883486ca3cf6"},
     {:porcelain, "~> 2.0.1"}]
  end
end
