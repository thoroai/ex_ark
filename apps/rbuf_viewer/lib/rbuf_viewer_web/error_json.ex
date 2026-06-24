defmodule RbufViewerWeb.ErrorJSON do
  def render(template, _assigns) do
    %{error: %{template: template}}
  end
end
