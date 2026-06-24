import Config

config :rbuf_viewer, RbufViewerWeb.Endpoint,
  adapter: Bandit.PhoenixAdapter,
  http: [ip: {127, 0, 0, 1}, port: 4001],
  check_origin: false,
  code_reloader: true,
  debug_errors: true,
  secret_key_base: "QKx8cQ7Qe7k7Lx4R4m8m3oYbX2n1f8JjQ3v5p1L2j5aYx9p9h6w4X3b1N9j2v8c7"

config :phoenix_live_view,
  debug_heex_annotations: true,
  debug_attributes: true,
  enable_expensive_runtime_checks: true

config :logger, :console, format: "[$level] $message\n"
