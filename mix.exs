defmodule Sentinel.MixProject do
  use Mix.Project

  def project do
    [
      app: :valheim_sentinel,
      version: "0.1.2",
      elixir: "~> 1.12",
      start_permanent: Mix.env() == :prod,
      deps: deps()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      mod: {Sentinel.Application, []},
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:nostrum, github: "Kraigie/nostrum"},
      {:dotenv_parser, "~> 1.2"},
      {:phoenix_pubsub, "~> 2.0"},
      {:timex, "~> 3.0"}
    ]
  end
end
