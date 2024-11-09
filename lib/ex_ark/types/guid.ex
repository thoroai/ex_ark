defmodule ExArk.Types.Guid do
  use ExArk.Serdes.Deserializable

  @impl Deserializable
  def read(
        %InputStream{
          bytes: <<hi::binary-size(8), lo::binary-size(8), rest::binary>>,
          offset: offset
        } = stream
      ) do
    hi = hi |> :binary.decode_unsigned(:little) |> :binary.encode_unsigned(:big)
    lo = lo |> :binary.decode_unsigned(:little) |> :binary.encode_unsigned(:big)

    {:ok,
     %Result{
       stream: %{stream | bytes: rest, offset: offset + 8},
       reified: Ecto.UUID.load(hi <> lo)
     }}
  rescue
    ArgumentError ->
      {:error, :bad_guid}
  end
end
