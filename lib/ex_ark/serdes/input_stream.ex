defmodule ExArk.Serdes.InputStream do
  @moduledoc """
  Input stream module.
  """

  use TypedStruct

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

  @spec read(t(), Field.t(), Registry.t()) :: {:ok, InputStream.Result.t()} | InputStream.failure()
  def read(%__MODULE__{} = stream, %Field{} = field, %Registry{} = registry) do
    if Field.optional?(field) do
      with {:ok, %Result{stream: stream, reified: present}} <- Primitives.read(:bool, stream) do
        if present do
          do_read(stream, field, registry)
        else
          {:ok, %Result{stream: stream}}
        end
      end
    else
      do_read(stream, field, registry)
    end
  end

  defp do_read(stream, field, registry) do
    type = String.to_existing_atom(field.type)

    cond do
      Types.primitive?(type) ->
        Primitives.read(type, stream)

      Types.enum?(type) ->
        type = registry.enums[field.object_type].enum_class
        Primitives.read(type, stream)

      Types.complex?(type) ->
        case Types.get_complex_module_for_type(type).read(stream, field, registry) do
          {:error, _} = error ->
            log_field_error(field, error)
            error

          {:ok, result} ->
            {:ok, result}
        end

      true ->
        {:error, :unknown_field_type}
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
