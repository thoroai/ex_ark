defmodule ExArk.Serdes.InputStream do
  @moduledoc """
  Input stream for deserialization.
  """

  use TypedStruct

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Types
  alias ExArk.Types.Primitives

  require Logger

  defmodule Result do
    @moduledoc """
    Typed structure for input stream read results
    """
    use TypedStruct

    typedstruct do
      field :reified, any()
      field :stream, InputStream.t()
    end
  end

  @type name :: any()
  @type context :: any()
  @type failure :: {:error, name(), context(), Result.t()}

  typedstruct do
    field :bytes, binary(), default: <<>>
    field :offset, integer(), default: 0
    field :has_more_sections, bool(), default: false
  end

  @spec advance(t(), non_neg_integer()) :: t()
  def advance(%__MODULE__{} = stream, count) do
    <<_drop::binary-size(count), rest::binary>> = stream.bytes
    %__MODULE__{stream | bytes: rest, offset: stream.offset + count}
  end

  @spec read(t(), Field.t(), Registry.t()) :: {:ok, Result.t()} | failure()
  def read(%__MODULE__{} = stream, %Field{} = field, %Registry{} = registry) do
    if Field.optional?(field) do
      with {:ok, %Result{stream: stream, reified: present}} <- Primitives.read(:bool, stream) do
        if present do
          read_field(stream, field, registry)
        else
          {:ok, %Result{stream: stream}}
        end
      end
    else
      read_field(stream, field, registry)
    end
  end

  defp read_field(stream, %Field{type: type} = field, registry) do
    cond do
      Types.primitive_type?(type) ->
        read_field_primitive(stream, type)

      Types.enum_type?(type) ->
        read_field_enum(stream, field, registry)

      Types.complex_type?(type) ->
        read_field_complex(stream, field, registry, type)

      true ->
        {:error, :unknown_field_type}
    end
  end

  defp read_field_primitive(stream, type) do
    Primitives.read(type, stream)
  end

  defp read_field_enum(stream, field, registry) do
    type = registry.enums[field.object_type].enum_class
    Primitives.read(type, stream)
  end

  defp read_field_complex(stream, field, registry, type) do
    mod = Types.get_complex_module_for_type(String.to_existing_atom(type))

    case mod.read(stream, field, registry) do
      {:error, _} = error ->
        log_field_error(field, error)
        error

      {:ok, result} ->
        {:ok, result}
    end
  end

  defp log_field_error(%{name: nil} = field, error) do
    Logger.error("Got error deserializing field (object type: #{field.object_type}): #{inspect(error)}",
      domain: [:ex_ark]
    )
  end

  defp log_field_error(field, error) do
    Logger.error("Got error deserializing field #{field.name} (object type: #{field.object_type}): #{inspect(error)}",
      domain: [:ex_ark]
    )
  end
end
