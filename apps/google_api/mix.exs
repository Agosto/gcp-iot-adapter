defmodule GoogleApi.Mixfile do
  use Mix.Project

  def project do
    [app: :google_api,
     version: "1.0.1",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     deps: deps,
     preferred_cli_env: [espec: :test]]
  end

  def application do
    [applications: [:logger, :httpoison, :oauth_jwt, :ex_json_schema, :exjsx, :uri_template]]
  end

  defp deps do
    [
      {:espec, "~> 0.8.17", only: :test},
      {:httpoison, "~> 0.8.2"},
      #{:poison, "~> 2.1.0"},
      {:ex_json_schema, "~> 0.3.1"},
      {:exjsx, "~> 3.2"},
      {:uri_template, "~> 1.2"},
      {:oauth_jwt, in_umbrella: true}
    ]
  end
end
