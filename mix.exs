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
     {:carrier, git: "git@github.com:operable/carrier", ref: "8cffbbc389b1cff4e9ea32a8a2952524f9812c41"}]
  end
end
