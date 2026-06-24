defmodule RbufViewer.Downloads do
  @moduledoc false

  use GenServer

  @table :rbuf_viewer_downloads

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  def put(bytes, filename, content_type \\ "application/octet-stream") when is_binary(bytes) do
    token = Base.url_encode64(:crypto.strong_rand_bytes(16), padding: false)

    true =
      :ets.insert(
        @table,
        {token, %{bytes: bytes, filename: filename, content_type: content_type}}
      )

    token
  end

  def fetch(token) when is_binary(token) do
    case :ets.lookup(@table, token) do
      [{^token, payload}] -> {:ok, payload}
      [] -> :error
    end
  end

  @impl true
  def init(_opts) do
    table = :ets.new(@table, [:named_table, :public, :set, read_concurrency: true])
    {:ok, table}
  end
end
