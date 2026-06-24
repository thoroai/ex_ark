defmodule RbufViewerWeb.DownloadController do
  use RbufViewerWeb, :controller

  def show(conn, %{"token" => token}) do
    case RbufViewer.Downloads.fetch(token) do
      {:ok, %{bytes: bytes, filename: filename, content_type: content_type}} ->
        conn
        |> put_resp_content_type(content_type)
        |> put_resp_header("content-disposition", ~s(attachment; filename="#{filename}"))
        |> send_resp(200, bytes)

      :error ->
        send_resp(conn, 404, "download not found")
    end
  end
end
