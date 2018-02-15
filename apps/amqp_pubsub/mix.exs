defmodule AmqpPubsub.Mixfile do
  use Mix.Project

  def project do
    [app: :amqp_pubsub,
     version: "1.0.3",
     build_path: "../../_build",
     config_path: "../../config/config.exs",
     deps_path: "../../deps",
     lockfile: "../../mix.lock",
     elixir: "~> 1.2",
     escript: [main_module: AmqpPubsub.Main, embed_elixir: true],
     build_embedded: Mix.env == :prod,
     start_permanent: Mix.env == :prod,
     description: "Google IoT Adapter - RabbitMQ to Google Cloud Pub Sub",
     deps: deps,
     preferred_cli_env: [espec: :test]]
  end

  def application do
    [applications: [:logger, :ex_doc, :earmark, :conform_exrm, :amqp, :exjsx, :conform, :httpoison, :poison, :oauth_jwt, :uri_template, :google_api, :json_web_token],
     mod: {AmqpPubsub, []}]
  end

  defp deps do
    [{:amqp, "0.1.4"},
     {:google_api, in_umbrella: true},
     {:json_web_token, "~> 0.2"},
     {:exrm, "~> 1.0.4"},
     {:conform, "~> 2.0.0"},
     {:conform_exrm, github: "bitwalker/conform_exrm"},
     {:earmark, "~> 0.1"},
     {:ex_doc, "~> 0.11"},
     {:espec, "~> 0.8.17", only: :test}
   ]
  end

end
