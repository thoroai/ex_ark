defmodule ExArk.Serdes.Deserializable do
  @moduledoc """
  Deserialization behaviour
  """

  alias ExArk.Registry
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

  @callback read(stream :: InputStream.t(), registry :: Registry.t()) ::
              {:ok, Result.t()} | failure()

  defmacro __using__(_) do
    quote do
      @behaviour ExArk.Serdes.Deserializable
      alias ExArk.Serdes.Deserializable
      alias ExArk.Serdes.Deserializable.Result
      alias ExArk.Serdes.InputStream

      def read(stream), do: {:error, :not_implemented}
      def read(stream, registry), do: read(stream)

      defoverridable read: 1, read: 2
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
  alias ExArk.Serdes.OptionalGroupHeader

  @spec read(Registry.t(), Schema.t(), Path.t()) :: {:ok, any()} | {:error, any()}
  def read(%Registry{} = registry, %Schema{} = schema, path) do
    case File.read(path) do
      {:ok, data} ->
        deserialize(registry, schema, %InputStream{bytes: data})

      error ->
        error
    end
  end

  defp deserialize(registry, schema, stream) do
    with {:ok, %Result{stream: stream}} <- BitstreamHeader.read(stream),
         {:ok, %Result{stream: stream}} <- deserialize_fields(schema.fields, stream, registry) do
      deserialize_groups(schema.groups, stream, registry)
    end
  end

  defp deserialize_fields(fields, stream, registry) do
    updated_stream =
      Enum.reduce(fields, stream, fn field, stream ->
        {:ok, %Result{stream: updated_stream}} =
          get_type_module_for(field.type).read(stream, registry)

        updated_stream
      end)

    {:ok, %Result{stream: updated_stream}}
  end

  defp deserialize_groups(_groups, %InputStream{has_more_sections: false} = stream, _registry),
    do: {:ok, %Result{stream: stream}}

  defp deserialize_groups(groups, stream, registry) do
    deserialize_group(groups, stream, registry)
    deserialize_groups(groups, stream, registry)
  end

  defp deserialize_group(groups, stream, registry) do
    case OptionalGroupHeader.read(stream) do
      {:ok, %Result{stream: stream, reified: header}} ->
        group = Enum.find(groups, fn group -> group.identifier == header.identifier end)

        if group != nil do
          deserialize_fields(group.fields, stream, registry)
        else
          {:ok, %Result{stream: advance_stream(stream, header)}}
        end

      error ->
        error
    end
  end

  defp advance_stream(%InputStream{} = stream, %OptionalGroupHeader{} = header) do
    <<_drop::binary-size(header.group_size), rest::binary>> = stream.bytes
    %InputStream{stream | bytes: rest, offset: stream.offset + header.group_size}
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

      "fixed_size_array" ->
        nil

      "arraylist" ->
        nil

      "dictionary" ->
        nil

      "object" ->
        nil

      "enum" ->
        nil

      "variant" ->
        nil

      _ ->
        raise RuntimeError, message: "unknown type: #{inspect(typestr)}"
    end
  end
end
