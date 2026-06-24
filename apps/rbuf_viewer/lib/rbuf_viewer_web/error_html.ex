defmodule RbufViewerWeb.ErrorHTML do
  use RbufViewerWeb, :html

  def render(template, _assigns),
    do:
      Phoenix.HTML.raw(
        ~s(<div class="error-page"><h1>Request failed</h1><p>Template: #{template}</p></div>)
      )
end
