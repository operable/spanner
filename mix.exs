defmodule Spanner.Mixfile do
  use Mix.Project

  def project do
    [app: :spanner,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger]]
  end

  defp deps do
    [{:piper, git: "git@github.com:operable/piper", ref: "91495c22904a15c5bacbbd0a2bed743e76da967e"},
     {:carrier, git: "git@github.com:operable/carrier", ref: "981db6c9a5698dee2b6966b99519c82fd68a6d54"}]
  end
end
