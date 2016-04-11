defmodule Awsex.Mixfile do
  use Mix.Project

  def project do
    [app: :awsex,
     version: "0.0.1",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :httpoison, :poison, :crypto, :tzdata],
     mod: {Awsex, []}]
  end

  defp deps do
    [{:httpoison, "~> 0.8"},
     {:poison, "~> 2.1"},
     {:timex, "~> 2.1"},
     {:ex_doc, "~> 0.11", only: :dev}]
  end
end
