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
    [{:piper, git: "git@github.com:operable/piper", ref: "f665a77a0ee6ff32438b599071ea01ee1d8cce46"},
     {:carrier, git: "git@github.com:operable/carrier", ref: "04704acfa02bc1783ca3523b4f37972f6e904720"},
     {:porcelain, "~> 2.0.1"}]
  end
end
