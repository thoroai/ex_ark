defmodule ExArk.Serdes.InputStream do
  @moduledoc """
  Input stream module.
  """

  use TypedStruct

  alias ExArk.Ir.ContainerField
  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.InputStream
  alias ExArk.Types
  alias ExArk.Types.Primitives

  require Logger

  @type failure :: {:error, any()}

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

  typedstruct do
    field :bytes, binary()
    field :offset, integer(), default: 0
    field :has_more_sections, bool(), default: false
  end

  @spec advance(t(), non_neg_integer()) :: t()
  def advance(%__MODULE__{} = stream, count) do
    <<_drop::binary-size(count), rest::binary>> = stream.bytes
    %__MODULE__{stream | bytes: rest, offset: stream.offset + count}
  end

  def read(%__MODULE__{} = stream, %ContainerField{} = container_field, %Registry{} = registry) do
    type = String.to_existing_atom(container_field.type)

    cond do
      Types.primitive?(type) ->
        Primitives.read(type, stream)

      Types.enum?(type) ->
        type = registry.enums[container_field.object_type].enum_class
        Primitives.read(type, stream)

      type == :object ->
        Types.get_complex_module_for_type(type).read(stream, container_field, registry)

      true ->
        {:error, :bad_stream}
    end
  end

  def read(%__MODULE__{} = stream, %Field{} = field, %Registry{} = registry) do
    type = String.to_existing_atom(field.type)

    cond do
      Types.primitive?(type) ->
        case Primitives.read(type, stream) do
          {:ok, %Result{reified: value}} = result ->
            Logger.debug("Deserialized primitive '#{field.name}': #{inspect(value)}")
            result

          error ->
            error
        end

      Types.enum?(type) ->
        type = registry.enums[field.object_type].enum_class

        case Primitives.read(type, stream) do
          {:ok, %Result{reified: value}} = result ->
            Logger.debug("Deserialized primitive enum '#{field.name}': #{inspect(value)}")
            result

          error ->
            error
        end

      Types.complex?(type) ->
        Logger.debug("Deserializing complex ('#{type}') field '#{field.name}'")
        Types.get_complex_module_for_type(type).read(stream, field, registry)

      true ->
        {:error, :bad_stream}
    end
  end
end
