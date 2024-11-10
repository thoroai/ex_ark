defmodule ExArk.Types.Uint8 do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-unsigned-integer-size(8), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 1}, reified: v}}
  end
end

defmodule ExArk.Types.Uint16 do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-unsigned-integer-size(16), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 2}, reified: v}}
  end
end

defmodule ExArk.Types.Uint32 do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-unsigned-integer-size(32), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4}, reified: v}}
  end
end

defmodule ExArk.Types.Uint64 do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-unsigned-integer-size(64), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end
end

defmodule ExArk.Types.Int8 do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-signed-integer-size(8), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 1}, reified: v}}
  end
end

defmodule ExArk.Types.Int16 do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-signed-integer-size(16), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 2}, reified: v}}
  end
end

defmodule ExArk.Types.Int32 do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-signed-integer-size(32), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4}, reified: v}}
  end
end

defmodule ExArk.Types.Int64 do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-signed-integer-size(64), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end
end

defmodule ExArk.Types.Float do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-float-size(32), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 4}, reified: v}}
  end
end

defmodule ExArk.Types.Double do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<v::little-float-size(64), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 8}, reified: v}}
  end
end

defmodule ExArk.Types.Bool do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(%InputStream{bytes: <<0::size(8), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 1}, reified: false}}
  end

  def read(%InputStream{bytes: <<_::size(8), rest::binary>>, offset: offset} = stream) do
    {:ok, %Result{stream: %{stream | bytes: rest, offset: offset + 1}, reified: true}}
  end
end
