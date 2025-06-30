defmodule ExArk.Serdes.OutputStream do
  @moduledoc """
  Output stream for serialization.
  """

  use TypedStruct

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Types
  alias ExArk.Types.Primitives

  require Logger

  @type failure :: {:error, any()}

  typedstruct enforce: true do
    field :bytes, binary(), default: <<>>
    field :offset, non_neg_integer(), default: 0
  end

  @spec advance(t(), non_neg_integer()) :: t()
  def advance(%__MODULE__{bytes: bytes, offset: offset} = stream, count) do
    %{stream | bytes: bytes <> :binary.copy(<<0>>, count), offset: offset + count}
  end

  @spec append(t(), binary()) :: t()
  def append(%__MODULE__{bytes: bytes, offset: offset} = stream, new_bytes) do
    %{stream | bytes: bytes <> new_bytes, offset: offset + byte_size(new_bytes)}
  end

  @spec write(t(), Field.t(), any(), Registry.t()) :: {:ok, t()} | failure()
  def write(%__MODULE__{} = stream, %Field{type: _type} = field, data, registry) do
    write_field(stream, field, data, registry)
  end

  @spec write_with_type(t(), String.t(), any(), Registry.t()) :: {:ok, t()} | failure()
  def write_with_type(%__MODULE__{} = stream, type, data, registry) do
    write_field(stream, Field.new(type), data, registry)
  end

  defp write_field(%__MODULE__{} = stream, %Field{type: type} = field, data, registry) do
    cond do
      Types.primitive_type?(type) ->
        write_field_primitive(stream, type, data)

      Types.enum_type?(type) ->
        write_field_enum(stream, field, data, registry)

      Types.complex_type?(type) ->
        write_field_complex(stream, field, data, registry, type)

      Map.has_key?(registry.schemas, field.type) ->
        write_field_schema(stream, field, data, registry)

      true ->
        write_field_unknown(field)
    end
  end

  defp write_field_primitive(stream, type, data) do
    Primitives.write(type, data, stream)
  end

  defp write_field_enum(stream, field, data, registry) do
    enum_type = registry.enums[field.object_type].enum_class
    Primitives.write(enum_type, data, stream)
  end

  defp write_field_complex(stream, field, data, registry, type) do
    mod = Types.get_complex_module_for_type(String.to_existing_atom(type))
    mod.write(stream, field, data, registry)

    case mod.write(stream, field, data, registry) do
      {:error, _} = error ->
        log_field_error(field, error)
        error

      {:ok, result} ->
        {:ok, result}
    end
  end

  defp write_field_schema(_stream, _field, _data, _registry) do
    raise RuntimeError, "Not yet implemented"
  end

  defp write_field_unknown(field) do
    raise ArgumentError, "Unknown field type: #{inspect(field.type)}"
  end

  defp log_field_error(%{name: nil} = field, error) do
    Logger.error("Got error serializing field (object type: #{field.object_type}): #{inspect(error)}",
      domain: [:ex_ark]
    )
  end

  defp log_field_error(field, error) do
    Logger.error("Got error serializing field #{field.name} (object type: #{field.object_type}): #{inspect(error)}",
      domain: [:ex_ark]
    )
  end
end
