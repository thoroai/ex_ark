defmodule ExArk.Serdes.Binary.Fields.Arraylist do
  @moduledoc """
  Module for handling array lists
  """

  alias ExArk.Ir.Field
  alias ExArk.Registry
  alias ExArk.Serdes.Binary
  alias ExArk.Serdes.Binary.Fields
  alias ExArk.Serdes.Binary.Fields.Primitives
  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.InputStream.Result
  alias ExArk.Serdes.Binary.OutputStream

  require Logger

  #
  # +----------+--------+--------+-----+--------+
  # | Size (N) | Type 1 | Type 2 | ... | Type N |
  # +----------+--------+--------+-----+--------+
  #

  @spec read(InputStream.t(), Field.t(), Registry.t()) ::
          {:ok, Result.t()} | Binary.deserialization_failure()
  def read(%InputStream{} = stream, %Field{} = field, %Registry{} = registry) do
    {:ok, %Result{stream: stream, reified: size}} = Primitives.read(:uint32, stream)
    read(size, stream, field, registry)
  end

  defp read(0 = _size, %InputStream{} = stream, %Field{} = _field, %Registry{} = _registry),
    do: {:ok, %Result{stream: stream, reified: []}}

  defp read(size, stream, field, registry) do
    reply = {:ok, %Result{stream: stream, reified: []}}

    result =
      Enum.reduce_while(1..size, reply, fn i, {_, result} ->
        case Fields.read(result.stream, field.ctr_value_type, registry) do
          {:ok, %Result{stream: stream, reified: item}} ->
            {:cont, {:ok, %Result{stream: stream, reified: [item] ++ result.reified}}}

          {:error, name, context, %Result{} = result} ->
            Logger.error("Error #{inspect(name)} deserializing arraylist item #{i} (of #{size}): #{inspect(context)}",
              domain: [:ex_ark]
            )

            {:halt, {:error, :bad_arraylist, nil, result}}
        end
      end)

    with {:ok, %Result{stream: stream, reified: items}} <- result do
      {:ok, %Result{stream: stream, reified: Enum.reverse(items)}}
    end
  end

  @spec write(OutputStream.t(), Field.t(), any(), Registry.t()) ::
          {:ok, OutputStream.t()} | Binary.serialization_failure()
  def write(%OutputStream{} = stream, %Field{} = _field, [], %Registry{} = _registry),
    do: Primitives.write(:uint32, 0, stream)

  def write(%OutputStream{} = stream, %Field{} = field, data, %Registry{} = registry) do
    size = length(data)
    {:ok, stream} = Primitives.write(:uint32, size, stream)

    data
    |> Enum.zip(1..size)
    |> Enum.reduce_while({:ok, stream}, fn {datum, i}, {:ok, stream} ->
      case Fields.write(stream, field.ctr_value_type, datum, registry) do
        {:ok, stream} ->
          {:cont, {:ok, stream}}

        {:error, name, context, %OutputStream{} = stream} ->
          Logger.error("Error #{inspect(name)} serializing arraylist item #{i} (of #{size}): #{inspect(context)}",
            domain: [:ex_ark]
          )

          {:halt, {:error, :bad_arraylist, nil, stream}}
      end
    end)
  end
end
