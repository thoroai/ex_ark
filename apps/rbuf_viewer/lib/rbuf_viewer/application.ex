defmodule RbufViewer.Application do
  use Application

  def start(_type, _args) do
    children = [
      RbufViewer.Downloads,
      {Phoenix.PubSub, name: RbufViewer.PubSub},
      RbufViewerWeb.Endpoint
    ]

    opts = [strategy: :one_for_one, name: RbufViewer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
