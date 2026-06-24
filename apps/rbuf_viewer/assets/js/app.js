import "phoenix_html"
import { Socket } from "phoenix"
import { LiveSocket } from "phoenix_live_view"
import "../css/app.css"

const csrfToken = document.querySelector("meta[name='csrf-token']")?.getAttribute("content")
const Hooks = {
  DownloadManager: {
    mounted() {
      this.handleEvent("download-file", ({ url }) => {
        const anchor = document.createElement("a")
        anchor.href = url
        anchor.rel = "noopener"
        anchor.download = ""
        document.body.appendChild(anchor)
        anchor.click()
        anchor.remove()
      })
    },
  },
}

const liveSocket = new LiveSocket("/live", Socket, { hooks: Hooks, params: { _csrf_token: csrfToken } })

liveSocket.connect()
window.liveSocket = liveSocket
