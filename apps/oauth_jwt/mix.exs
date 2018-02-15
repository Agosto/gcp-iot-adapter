defmodule OauthJwt.Mixfile do
  use Mix.Project

  def project do
    [app: :oauth_jwt,
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

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: [:logger, :httpoison, :poison, :json_web_token]]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      {:espec, "~> 0.8.17", only: :test},
      {:httpoison, "~> 0.8.2"},
      {:poison, "~> 2.1.0", override: true},
      {:json_web_token, "~> 0.2.5"},
      {:mock, "~> 0.1.3", only: :test}
    ]
  end
end
