import Config

config :rbuf_viewer, RbufViewerWeb.Endpoint,
  http: [ip: {127, 0, 0, 1}, port: 4002],
  secret_key_base: "testtesttesttesttesttesttesttesttesttesttesttesttesttesttesttest",
  server: false

config :logger, level: :warning
