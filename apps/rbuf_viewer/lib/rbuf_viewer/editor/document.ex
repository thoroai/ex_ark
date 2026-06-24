defmodule RbufViewer.Editor.Document do
  @moduledoc false

  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Registry
  alias ExArk.Serdes
  alias ExArk.Types

  defstruct mode: nil,
            registry: nil,
            schema: nil,
            schema_name: nil,
            object: nil,
            bytes: nil,
            source_label: nil,
            expanded_paths: MapSet.new([[]]),
            error: nil

  def blank do
    %__MODULE__{}
  end

  def from_loaded(%{
        registry: registry,
        schema: schema,
        schema_name: schema_name,
        object: object,
        bytes: bytes,
        mode: mode
      }) do
    %__MODULE__{
      mode: mode,
      registry: registry,
      schema: schema,
      schema_name: schema_name,
      object: object,
      bytes: bytes,
      expanded_paths: MapSet.new([[]])
    }
  end

  def from_schema(%Registry{} = registry, schema_name) when is_binary(schema_name) do
    schema = Map.fetch!(registry.schemas, schema_name)
    object = Serdes.default_value(%Field{type: "object", object_type: schema_name}, registry)

    %__MODULE__{
      mode: :draft,
      registry: registry,
      schema: schema,
      schema_name: schema_name,
      object: object,
      bytes: nil,
      expanded_paths: MapSet.new([[]])
    }
  end

  def toggle_path(%__MODULE__{} = doc, path) do
    expanded_paths =
      if MapSet.member?(doc.expanded_paths, path) do
        MapSet.delete(doc.expanded_paths, path)
      else
        MapSet.put(doc.expanded_paths, path)
      end

    %{doc | expanded_paths: expanded_paths}
  end

  def path_open?(%__MODULE__{} = doc, path) do
    MapSet.member?(doc.expanded_paths, path)
  end

  def path_open?(%{} = doc, path) do
    MapSet.member?(Map.get(doc, :expanded_paths, MapSet.new()), path)
  end

  def schema_fields(%Schema{} = schema) do
    schema.fields ++ Enum.flat_map(schema.groups, & &1.fields)
  end

  def field_for_path(%__MODULE__{schema: schema} = doc, path) do
    case resolve(doc, path) do
      {:ok, %{field: field}} -> field
      _ -> find_field(schema, path)
    end
  end

  def resolve(%__MODULE__{schema: schema, registry: registry, object: object}, path) do
    do_resolve(schema, object, registry, path, nil)
  end

  def update_value(%__MODULE__{} = doc, path, raw_value) do
    with {:ok, %{field: field}} <- resolve(doc, path),
         {:ok, coerced} <- coerce_value(field, raw_value, doc.registry) do
      {:ok, %{doc | object: put_at_path(doc.object, path, coerced)}}
    end
  end

  def set_variant_type(%__MODULE__{} = doc, path, schema_name) do
    with {:ok, %{field: %Field{type: "variant"} = field}} <- resolve(doc, path),
         variant <- Enum.find(field.variant_types, &(&1.object_type == schema_name)),
         %Schema{} = schema <- Map.get(doc.registry.schemas, schema_name) do
      if is_nil(variant) do
        {:error, :unknown_variant}
      else
        {:ok,
         doc
         |> put_object(path, Types.add_type(default_object(schema, doc.registry), schema))
         |> open_path(path)}
      end
    else
      nil -> {:error, :missing_schema}
      error -> error
    end
  end

  def add_item(%__MODULE__{} = doc, path) do
    with {:ok, %{field: field, value: value}} <- resolve(doc, path) do
      case field.type do
        "arraylist" ->
          item = Serdes.default_value(field.ctr_value_type, doc.registry)
          index = length(value || [])
          item_path = path ++ [{:index, index}]

          {:ok,
           doc
           |> put_object(path, value ++ [item])
           |> open_path(item_path)}

        "dictionary" ->
          case build_dictionary_entry(field, value, doc.registry) do
            {:ok, {key, entry}} ->
              entry_path = path ++ [{:dict_entry, key}]

              {:ok,
               doc
               |> put_object(path, Map.put(value, key, entry))
               |> open_path(entry_path)}

            error ->
              error
          end

        _ ->
          {:error, :unsupported_collection}
      end
    end
  end

  def remove_item(%__MODULE__{} = doc, path) do
    case split_parent(path) do
      {parent_path, {:index, index}} ->
        with {:ok, %{value: list, field: %Field{type: type}}} <- resolve(doc, parent_path),
             true <- type in ["array", "arraylist"] do
          new_list = List.delete_at(list, index)
          {:ok, %{doc | object: put_at_path(doc.object, parent_path, new_list)}}
        else
          _ -> {:error, :unsupported_collection}
        end

      {parent_path, {:dict_entry, key}} ->
        with {:ok, %{value: map, field: %Field{type: "dictionary"}}} <- resolve(doc, parent_path) do
          {:ok, %{doc | object: put_at_path(doc.object, parent_path, Map.delete(map, key))}}
        else
          _ -> {:error, :unsupported_collection}
        end

      _ ->
        {:error, :unsupported_collection}
    end
  end

  def reset_item(%__MODULE__{} = doc, path) do
    with {:ok, %{field: field}} <- resolve(doc, path) do
      {:ok,
       %{doc | object: put_at_path(doc.object, path, Serdes.default_value(field, doc.registry))}}
    end
  end

  def clear_collection(%__MODULE__{} = doc, path) do
    with {:ok, %{field: field, value: value}} <- resolve(doc, path) do
      case field.type do
        "arraylist" ->
          {:ok, %{doc | object: put_at_path(doc.object, path, [])}}

        "dictionary" ->
          {:ok, %{doc | object: put_at_path(doc.object, path, %{})}}

        "array" ->
          {:ok,
           %{
             doc
             | object:
                 put_at_path(doc.object, path, clear_fixed_array(field, value, doc.registry))
           }}

        _ ->
          {:error, :unsupported_collection}
      end
    end
  end

  def download_name(%__MODULE__{schema_name: schema_name, mode: mode}) do
    download_name(schema_name, mode)
  end

  def download_name(schema_name, mode) do
    suffix =
      case mode do
        :generic -> ".generic.rbuf"
        "generic" -> ".generic.rbuf"
        :typed -> ".typed.rbuf"
        "typed" -> ".typed.rbuf"
        _ -> ".typed.rbuf"
      end

    schema_slug = schema_name |> to_string() |> String.replace(~r/[^A-Za-z0-9_.-]+/, "_")
    "#{schema_slug}#{suffix}"
  end

  defp put_object(%__MODULE__{} = doc, path, value) do
    %{doc | object: put_at_path(doc.object, path, value)}
  end

  defp open_path(%__MODULE__{} = doc, path) do
    %{doc | expanded_paths: MapSet.put(doc.expanded_paths, path)}
  end

  defp clear_fixed_array(%Field{} = field, _value, registry) do
    for _ <- 1..field.array_size do
      Serdes.default_value(field.ctr_value_type, registry)
    end
  end

  defp build_dictionary_entry(%Field{} = field, value, registry) do
    case default_dictionary_key(field.ctr_key_type, value, registry) do
      {:error, reason} ->
        {:error, reason}

      key ->
        entry = Serdes.default_value(field.ctr_value_type, registry)
        {:ok, {key, entry}}
    end
  end

  defp default_dictionary_key(%Field{type: "string"}, map, _registry) do
    base = "new_key"
    unique_string_key(Map.keys(map), base, 1)
  end

  defp default_dictionary_key(%Field{type: "bool"}, map, _registry) do
    if Map.has_key?(map, false), do: true, else: false
  end

  defp default_dictionary_key(%Field{type: t}, map, _registry)
       when t in ["uint8", "uint16", "uint32", "uint64", "int8", "int16", "int32", "int64"] do
    next_integer_key(Map.keys(map))
  end

  defp default_dictionary_key(%Field{}, _map, _registry) do
    {:error, :unsupported_dictionary_key}
  end

  defp next_integer_key(keys) do
    keys
    |> Enum.filter(&is_integer/1)
    |> case do
      [] -> 0
      ints -> Enum.max(ints) + 1
    end
  end

  defp unique_string_key(keys, base, suffix) do
    candidate = if suffix == 1, do: base, else: "#{base}_#{suffix}"

    if Enum.member?(keys, candidate) do
      unique_string_key(keys, base, suffix + 1)
    else
      candidate
    end
  end

  defp split_parent([last]), do: {[], last}
  defp split_parent(path), do: Enum.split(path, length(path) - 1)

  defp do_resolve(%Schema{} = schema, value, _registry, [], field) do
    {:ok, %{schema: schema, value: value, field: field}}
  end

  defp do_resolve(%Schema{} = schema, value, registry, [{:field, name} | rest], _field) do
    field = find_field(schema, name)
    current = Map.get(value, String.to_atom(name))
    next_schema = schema_for_field(field, current, registry) || schema

    next_field =
      if rest == [] do
        field
      else
        case field.type do
          "object" -> nil
          "variant" -> nil
          _ -> field
        end
      end

    do_resolve(next_schema, current, registry, rest, next_field)
  end

  defp do_resolve(
         %Schema{} = schema,
         value,
         registry,
         [{:index, idx} | rest],
         %Field{type: type} = field
       )
       when type in ["array", "arraylist"] do
    current = Enum.at(value, idx)
    next_schema = schema_for_field(field.ctr_value_type, current, registry) || schema
    do_resolve(next_schema, current, registry, rest, field.ctr_value_type)
  end

  defp do_resolve(
         %Schema{} = schema,
         value,
         registry,
         [{:dict_entry, key} | rest],
         %Field{type: "dictionary"} = field
       ) do
    current = Map.get(value, key)
    next_schema = schema_for_field(field.ctr_value_type, current, registry) || schema
    do_resolve(next_schema, current, registry, rest, field.ctr_value_type)
  end

  defp do_resolve(%Schema{} = _schema, _value, _registry, _path, _field), do: {:error, :bad_path}

  defp schema_for_field(
         %Field{type: "object", object_type: object_type},
         _value,
         %Registry{} = registry
       ),
       do: Map.get(registry.schemas, object_type)

  defp schema_for_field(%Field{type: "variant"} = field, value, %Registry{} = registry) do
    object_type = Types.get_type(value)

    if is_binary(object_type),
      do: Map.get(registry.schemas, object_type),
      else: first_variant_schema(field, registry)
  end

  defp schema_for_field(_field, _value, _registry), do: nil

  defp first_variant_schema(%Field{variant_types: [first | _]}, %Registry{} = registry),
    do: Map.get(registry.schemas, first.object_type)

  defp first_variant_schema(%Field{}, _registry), do: nil

  defp find_field(%Schema{} = schema, name) do
    schema_fields(schema)
    |> Enum.find(fn %Field{name: field_name} -> field_name == name end)
  end

  defp put_at_path(%{} = map, [{:field, name} | rest], new_value) do
    key = String.to_atom(name)
    current = Map.get(map, key)
    Map.put(map, key, put_at_path(current, rest, new_value))
  end

  defp put_at_path(%{} = map, [{:dict_entry, key} | rest], new_value) do
    current = Map.get(map, key)
    Map.put(map, key, put_at_path(current, rest, new_value))
  end

  defp put_at_path(nil, [{:field, _} | _] = path, new_value),
    do: put_at_path(%{}, path, new_value)

  defp put_at_path(nil, [{:dict_entry, _} | _] = path, new_value),
    do: put_at_path(%{}, path, new_value)

  defp put_at_path(list, [{:index, idx} | rest], new_value) when is_list(list) do
    List.update_at(list, idx, &put_at_path(&1, rest, new_value))
  end

  defp put_at_path(_value, [], new_value), do: new_value

  defp default_object(%Schema{} = schema, %Registry{} = registry) do
    schema_fields(schema)
    |> Enum.map(fn field ->
      {String.to_atom(field.name), Serdes.default_value(field, registry)}
    end)
    |> Map.new()
  end

  defp coerce_value(%Field{type: "bool"}, raw, _registry) when is_binary(raw) do
    case raw do
      "true" -> {:ok, true}
      "false" -> {:ok, false}
      _ -> {:error, :bad_bool}
    end
  end

  defp coerce_value(%Field{type: t}, raw, _registry)
       when t in [
              "uint8",
              "uint16",
              "uint32",
              "uint64",
              "int8",
              "int16",
              "int32",
              "int64",
              "steady_time_point",
              "system_time_point"
            ] do
    case Integer.parse(raw) do
      {int, ""} -> {:ok, int}
      _ -> {:error, :bad_integer}
    end
  end

  defp coerce_value(%Field{type: t}, raw, _registry) when t in ["float", "double"] do
    case Float.parse(raw) do
      {float, ""} -> {:ok, float}
      _ -> {:error, :bad_float}
    end
  end

  defp coerce_value(%Field{type: "string"}, raw, _registry), do: {:ok, raw}
  defp coerce_value(%Field{type: "guid"}, raw, _registry), do: {:ok, raw}

  defp coerce_value(%Field{type: "byte_buffer"}, raw, _registry) do
    case parse_hex(raw) do
      {:ok, bytes} -> {:ok, bytes}
      error -> error
    end
  end

  defp coerce_value(%Field{type: "enum"} = field, raw, registry) do
    enum = Map.fetch!(registry.enums, field.object_type)

    case enum.enum_type do
      :value ->
        {:ok, String.to_existing_atom(raw)}

      :bitmask ->
        {:ok, Enum.map(List.wrap(raw), &String.to_existing_atom/1)}
    end
  end

  defp coerce_value(%Field{type: "variant"} = _field, raw, registry) do
    schema = Map.fetch!(registry.schemas, raw)
    {:ok, put_variant_type(default_object(schema, registry), raw)}
  end

  defp coerce_value(_field, raw, _registry), do: {:ok, raw}

  defp put_variant_type(object, schema_name) do
    Map.put(object, :__ark_schema, schema_name)
  end

  defp parse_hex(raw) when is_binary(raw) do
    raw
    |> String.replace(~r/[^0-9A-Fa-f]/, "")
    |> then(fn hex ->
      if rem(byte_size(hex), 2) == 1 do
        {:error, :bad_hex}
      else
        {:ok, hex_decode(hex, <<>>)}
      end
    end)
  end

  defp hex_decode(<<>>, acc), do: acc

  defp hex_decode(<<hi::binary-size(2), rest::binary>>, acc) do
    <<byte::8>> = <<String.to_integer(hi, 16)>>
    hex_decode(rest, <<acc::binary, byte>>)
  end
end
