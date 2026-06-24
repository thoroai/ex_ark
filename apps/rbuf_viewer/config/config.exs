import Config

config :rbuf_viewer,
  ecto_repos: []

config :esbuild,
  version: "0.25.0"

config :rbuf_viewer, RbufViewerWeb.Endpoint,
  url: [host: "localhost"],
  render_errors: [
    formats: [html: RbufViewerWeb.ErrorHTML, json: RbufViewerWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: RbufViewer.PubSub,
  live_view: [signing_salt: "rbuf-viewer-salt"]

config :phoenix, :json_library, Jason

import_config "#{config_env()}.exs"
