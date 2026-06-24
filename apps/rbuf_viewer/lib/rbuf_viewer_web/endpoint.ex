defmodule RbufViewerWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :rbuf_viewer

  socket("/live", Phoenix.LiveView.Socket)

  plug(Plug.Static,
    at: "/",
    from: :rbuf_viewer,
    gzip: false,
    only: ~w(assets favicon.ico robots.txt)
  )

  if Mix.env() == :dev do
    plug(Tidewave)
  end

  if code_reloading? do
    plug(Phoenix.CodeReloader)
  end

  plug(Plug.RequestId)
  plug(Plug.Telemetry, event_prefix: [:phoenix, :endpoint])

  plug(Plug.Parsers,
    parsers: [:urlencoded, :multipart, :json],
    pass: ["*/*"],
    json_decoder: Jason
  )

  plug(Plug.MethodOverride)
  plug(Plug.Head)

  plug(Plug.Session,
    store: :cookie,
    key: "_rbuf_viewer_key",
    signing_salt: "rbuf-viewer-session"
  )

  plug(RbufViewerWeb.Router)
end
