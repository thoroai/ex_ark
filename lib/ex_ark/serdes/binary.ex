defmodule ExArk.Serdes.Binary do
  @moduledoc false

  alias ExArk.Serdes.Binary.InputStream
  alias ExArk.Serdes.Binary.OutputStream

  @type name :: any()
  @type context :: any()
  @type serialization_failure :: {:error, name(), context(), OutputStream.t()}
  @type deserialization_failure :: {:error, name(), context(), InputStream.Result.t()}
end
