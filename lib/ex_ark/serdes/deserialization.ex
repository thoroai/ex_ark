defmodule ExArk.Serdes.Deserializable do
  @moduledoc """
  Deserialization behaviour
  """

  alias ExArk.Serdes.InputStream

  @type failure :: {:error, any()}

  defmodule Result do
    use TypedStruct

    typedstruct do
      field :reified, any()
      field :stream, InputStream.t()
    end
  end

  @callback read(stream :: InputStream.t()) :: {:ok, Result.t()} | failure()

  defmacro __using__(_) do
    quote do
      @behaviour ExArk.Serdes.Deserializable
      alias ExArk.Serdes.Deserializable
      alias ExArk.Serdes.Deserializable.Result
      alias ExArk.Serdes.InputStream
    end
  end
end

defmodule ExArk.Serdes.Deserialization do
  @moduledoc """
  Ark deserialization utilities.
  """

  alias ExArk.Registry
  alias ExArk.Ir.Schema
  alias ExArk.Serdes.Deserializable.Result
  alias ExArk.Serdes.InputStream
  alias ExArk.Serdes.BitstreamHeader

  @spec read(Registry.t(), Schema.t(), Path.t()) :: {:ok, any()} | {:error, any()}
  def read(%Registry{} = registry, %Schema{} = schema, path) do
    case File.read(path) do
      {:ok, data} ->
        deserialize(registry, schema, data)

      error ->
        error
    end
  end

  defp deserialize(_registry, schema, data) do
    {:ok, %Result{stream: stream}} = BitstreamHeader.read(%InputStream{bytes: data})

    Enum.reduce(schema.fields, stream, fn field, stream ->
      {:ok, %Result{stream: updated_stream}} = get_type_module_for(field.type).read(stream)
      updated_stream
    end)
  end

  defp get_type_module_for(typestr) do
    case typestr do
      "bool" ->
        ExArk.Types.Bool

      "uint8" ->
        ExArk.Types.Uint8

      "uint16" ->
        ExArk.Types.Uint16

      "uint32" ->
        ExArk.Types.Uint32

      "uint64" ->
        ExArk.Types.Uint64

      "int8" ->
        ExArk.Types.Int8

      "int16" ->
        ExArk.Types.Int16

      "int32" ->
        ExArk.Types.Int32

      "int64" ->
        ExArk.Types.Int64

      "double" ->
        ExArk.Types.Double

      "float" ->
        ExArk.Types.Float

      "string" ->
        ExArk.Types.String

      "guid" ->
        ExArk.Types.Guid

      "byte_buffer" ->
        ExArk.Types.ByteBuffer

      "duration" ->
        ExArk.Types.Duration

      "steady_time_point" ->
        ExArk.Types.SteadyTimePoint

      "system_time_point" ->
        ExArk.Types.SystemTimePoint

      _ ->
        raise RuntimeError, message: "unknown type: #{inspect(typestr)}"
    end
  end
end
