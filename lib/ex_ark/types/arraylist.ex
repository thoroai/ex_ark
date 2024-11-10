defmodule ExArk.Types.Arraylist do
  use ExArk.Serdes.Deserializable

  #
  # +-----------+--------+--------+-----+--------+
  # | Count (N) | Type 1 | Type 2 | ... | Type N |
  # +-----------+--------+--------+-----+--------+
  #

  @impl Deserializable
  def read(
        %InputStream{bytes: <<len::little-unsigned-integer-size(32), rest::binary>>, offset: offset} = stream,
        registry
      ) do
    stream = %{stream | bytes: rest, offset: offset + 4 + len}

    {stream, items} =
      Enum.reduce(1..len, {stream, []}, fn _i, {stream, items} ->
        {:ok, %Result{stream: stream, reified: item}} = read(stream, registry)
        {stream, [item] ++ items}
      end)

    {:ok, %Result{stream: stream, reified: Enum.reverse(items)}}
  end
end
