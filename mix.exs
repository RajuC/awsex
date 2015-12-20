defmodule Awsex.Mixfile do
  use Mix.Project

  def project do
    [app: :awsex,
     version: "0.0.1",
     elixir: "~> 1.1",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps]
  end

  def application do
    [applications: [:logger, :httpoison, :poison, :crypto, :tzdata],
     mod: {Awsex, []}]
  end

  defp deps do
    [{:httpoison, "~> 0.7"},
     {:poison, "~> 1.5"},
     {:timex, "~> 1.0-rc"}]
  end
end
