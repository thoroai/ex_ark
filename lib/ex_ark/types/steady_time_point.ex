defmodule ExArk.Types.SteadyTimePoint do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-signed-integer-size(64), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end
end
