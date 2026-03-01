defmodule ExArk.Generate.SchemaBuilder do
  @moduledoc """
  Generates `defmodule` AST for Ark schema types.

  Each generated schema module provides:

  - A `TypedStruct`-backed struct with correctly-typed fields
  - `serialize_to_binary/1`, `serialize_to_json/1`
  - `deserialize_from_binary/1`, `deserialize_from_json/1`
  - `__ark_schema_name/0` — returns the fully-qualified Ark schema name
  - `to_map/1`, `from_map/1` — `@doc false` public helpers used by parent
    schema modules when converting nested structs

  Variant fields are handled by generated private functions named
  `__to_variant_FIELD__/1` and `__from_variant_FIELD__/1`.
  """

  alias ExArk.Generate.DocBuilder
  alias ExArk.Generate.Naming
  alias ExArk.Generate.TypeSpec
  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Registry

  @doc """
  Builds the `defmodule` AST for `schema` under `namespace`.

  `sub_registry_json` must be a JSON string for an `ExArk.Registry` that
  contains `schema` and all of its transitive dependencies — it is embedded
  as a compile-time constant and parsed once at module-load time.
  """
  @spec build(Schema.t(), Registry.t(), module(), String.t()) :: Macro.t()
  def build(%Schema{} = schema, %Registry{} = registry, namespace, sub_registry_json) do
    module_name = Naming.schema_module(schema, namespace)
    ark_name = Schema.object_name(schema)
    moduledoc = DocBuilder.schema_moduledoc(schema, registry, namespace)

    all_fields = active_fields(schema)

    field_defs = build_field_defs(all_fields, registry, namespace)
    to_map_body = build_to_map_body(all_fields, registry, namespace)
    from_map_body = build_from_map_body(all_fields, registry, namespace)
    variant_defps = build_variant_defps(all_fields, registry, namespace)

    quote do
      defmodule unquote(module_name) do
        @moduledoc unquote(moduledoc)

        use TypedStruct

        alias ExArk.Registry

        @ark_registry_json unquote(sub_registry_json)
        @ark_registry Registry.build!(@ark_registry_json)
        @ark_schema_name unquote(ark_name)

        @typedoc "Struct representation of `#{unquote(ark_name)}`."
        typedstruct do
          (unquote_splicing(field_defs))
        end

        @doc """
        Returns the fully-qualified Ark schema name for this generated module.

        Useful when bridging between the generated struct API and the generic
        map-based API, for example when you need to pass the schema name to
        `ExArk.Generate.module_for/2` or to `ExArk` serialization functions.

            iex> #{unquote(module_name)}.__ark_schema_name()
            #{inspect(unquote(ark_name))}

        """
        @spec __ark_schema_name() :: String.t()
        def __ark_schema_name, do: @ark_schema_name

        @doc "Serializes this struct to Ark binary format."
        @spec serialize_to_binary(t()) :: {:ok, binary()} | {:error, any()}
        def serialize_to_binary(%__MODULE__{} = data) do
          ExArk.write_object_to_bytes(@ark_registry, @ark_schema_name, to_map(data))
        end

        @doc "Serializes this struct to Ark JSON format."
        @spec serialize_to_json(t()) :: {:ok, String.t()} | {:error, any()}
        def serialize_to_json(%__MODULE__{} = data) do
          ExArk.write_object_to_json(@ark_registry, @ark_schema_name, to_map(data))
        end

        @doc "Deserializes an Ark binary payload into this struct."
        @spec deserialize_from_binary(binary()) :: {:ok, t()} | {:error, any()}
        def deserialize_from_binary(bytes) do
          with {:ok, map} <-
                 ExArk.read_object_from_bytes(@ark_registry, @ark_schema_name, bytes) do
            {:ok, from_map(map)}
          end
        end

        @doc "Deserializes an Ark JSON payload into this struct."
        @spec deserialize_from_json(String.t()) :: {:ok, t()} | {:error, any()}
        def deserialize_from_json(json) do
          with {:ok, map} <-
                 ExArk.read_object_from_json(@ark_registry, @ark_schema_name, json) do
            {:ok, from_map(map)}
          end
        end

        @doc false
        @spec to_map(t()) :: map()
        def to_map(%__MODULE__{} = s) do
          unquote(to_map_body)
        end

        @doc false
        @spec from_map(map()) :: t()
        def from_map(map) do
          unquote(from_map_body)
        end

        unquote_splicing(variant_defps)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Field collection
  # ---------------------------------------------------------------------------

  # Returns [{field, nullable?}] for all active (non-removed) fields.
  # Group fields are always nullable (they may be absent from older messages).
  defp active_fields(%Schema{} = schema) do
    regular =
      schema.fields
      |> Enum.reject(&Field.removed?/1)
      |> Enum.map(&{&1, Field.optional?(&1)})

    group =
      schema.groups
      |> Enum.flat_map(& &1.fields)
      |> Enum.reject(&Field.removed?/1)
      |> Enum.map(&{&1, true})

    regular ++ group
  end

  # ---------------------------------------------------------------------------
  # typedstruct field definitions
  # ---------------------------------------------------------------------------

  defp build_field_defs(fields_with_nullable, registry, namespace) do
    Enum.map(fields_with_nullable, fn {field, nullable} ->
      name_atom = String.to_atom(field.name)
      type_ast = TypeSpec.for_field(field, registry, namespace, nullable: nullable)

      quote do
        field(unquote(name_atom), unquote(type_ast), enforce: unquote(!nullable))
      end
    end)
  end

  # ---------------------------------------------------------------------------
  # to_map/1 body
  # ---------------------------------------------------------------------------

  # Generates:
  #   [
  #     {:field_a, convert(s.field_a)},
  #     (if s.opt != nil, do: {:opt, convert(s.opt)}),
  #     ...
  #   ]
  #   |> Enum.reject(&is_nil/1)
  #   |> Map.new()
  #
  defp build_to_map_body(fields_with_nullable, registry, namespace) do
    entries =
      Enum.map(fields_with_nullable, fn {field, nullable} ->
        name_atom = String.to_atom(field.name)
        # AST for s.field_name (struct field access in the generated function)
        raw_val = quote do: s.unquote(name_atom)
        convert = to_map_convert(field, registry, namespace, raw_val)

        to_map_entry(name_atom, convert, nullable)
      end)

    quote do
      [unquote_splicing(entries)]
      |> Enum.reject(&is_nil/1)
      |> Map.new()
    end
  end

  # Returns the AST expression that converts `val_ast` to a plain map value.
  defp to_map_convert(
         %Field{type: "object", object_type: object_type},
         registry,
         namespace,
         val_ast
       ) do
    if Map.has_key?(registry.schemas, object_type) do
      mod = Naming.ark_name_to_module(object_type, namespace)
      quote do: unquote(mod).to_map(unquote(val_ast))
    else
      val_ast
    end
  end

  defp to_map_convert(%Field{type: "variant"} = field, _registry, _namespace, val_ast) do
    fn_name = to_variant_fn(field.name)
    quote do: unquote(fn_name)(unquote(val_ast))
  end

  defp to_map_convert(
         %Field{type: t, ctr_value_type: %Field{type: "object", object_type: object_type}},
         registry,
         namespace,
         val_ast
       )
       when t in ["array", "arraylist"] do
    if Map.has_key?(registry.schemas, object_type) do
      mod = Naming.ark_name_to_module(object_type, namespace)
      quote do: Enum.map(unquote(val_ast), &unquote(mod).to_map/1)
    else
      val_ast
    end
  end

  defp to_map_convert(
         %Field{
           type: "dictionary",
           ctr_value_type: %Field{type: "object", object_type: object_type}
         },
         registry,
         namespace,
         val_ast
       ) do
    if Map.has_key?(registry.schemas, object_type) do
      mod = Naming.ark_name_to_module(object_type, namespace)
      quote do: Map.new(unquote(val_ast), fn {k, v} -> {k, unquote(mod).to_map(v)} end)
    else
      val_ast
    end
  end

  defp to_map_convert(_field, _registry, _namespace, val_ast), do: val_ast

  # ---------------------------------------------------------------------------
  # from_map/1 body
  # ---------------------------------------------------------------------------

  defp build_from_map_body(fields_with_nullable, registry, namespace) do
    struct_fields =
      Enum.map(fields_with_nullable, fn {field, nullable} ->
        name_atom = String.to_atom(field.name)
        val_expr = from_map_convert(field, registry, namespace, name_atom, nullable)
        {name_atom, val_expr}
      end)

    quote do
      %__MODULE__{unquote_splicing(struct_fields)}
    end
  end

  defp from_map_convert(
         %Field{type: "object", object_type: object_type},
         registry,
         namespace,
         name_atom,
         nullable
       ) do
    if Map.has_key?(registry.schemas, object_type) do
      mod = Naming.ark_name_to_module(object_type, namespace)
      object_from_map_expr(mod, name_atom, nullable)
    else
      fetch_expr(name_atom, nullable)
    end
  end

  defp from_map_convert(%Field{type: "variant"} = field, _registry, _namespace, name_atom, nullable) do
    fn_name = from_variant_fn(field.name)

    if nullable do
      quote do
        case Map.get(map, unquote(name_atom)) do
          nil -> nil
          v -> unquote(fn_name)(v)
        end
      end
    else
      quote do: unquote(fn_name)(Map.fetch!(map, unquote(name_atom)))
    end
  end

  defp from_map_convert(
         %Field{type: t, ctr_value_type: %Field{type: "object", object_type: object_type}},
         registry,
         namespace,
         name_atom,
         nullable
       )
       when t in ["array", "arraylist"] do
    if Map.has_key?(registry.schemas, object_type) do
      mod = Naming.ark_name_to_module(object_type, namespace)
      list_expr = quote do: Enum.map(raw, &unquote(mod).from_map/1)
      wrap_nullable(name_atom, nullable, list_expr)
    else
      fetch_expr(name_atom, nullable)
    end
  end

  defp from_map_convert(
         %Field{
           type: "dictionary",
           ctr_value_type: %Field{type: "object", object_type: object_type}
         },
         registry,
         namespace,
         name_atom,
         nullable
       ) do
    if Map.has_key?(registry.schemas, object_type) do
      mod = Naming.ark_name_to_module(object_type, namespace)
      dict_expr = quote do: Map.new(raw, fn {k, v} -> {k, unquote(mod).from_map(v)} end)
      wrap_nullable(name_atom, nullable, dict_expr)
    else
      fetch_expr(name_atom, nullable)
    end
  end

  defp from_map_convert(_field, _registry, _namespace, name_atom, nullable) do
    fetch_expr(name_atom, nullable)
  end

  defp object_from_map_expr(mod, name_atom, false) do
    quote do: unquote(mod).from_map(Map.fetch!(map, unquote(name_atom)))
  end

  defp object_from_map_expr(mod, name_atom, true) do
    quote do
      case Map.get(map, unquote(name_atom)) do
        nil -> nil
        v -> unquote(mod).from_map(v)
      end
    end
  end

  # Builds the AST for one `to_map` list entry. Nullable entries are wrapped in
  # a conditional so they are omitted when the field is nil.
  defp to_map_entry(name_atom, convert, false) do
    quote do: {unquote(name_atom), unquote(convert)}
  end

  defp to_map_entry(name_atom, convert, true) do
    quote do
      if s.unquote(name_atom) != nil, do: {unquote(name_atom), unquote(convert)}
    end
  end

  defp fetch_expr(name_atom, false), do: quote(do: Map.fetch!(map, unquote(name_atom)))
  defp fetch_expr(name_atom, true), do: quote(do: Map.get(map, unquote(name_atom)))

  defp wrap_nullable(name_atom, false, body_expr) do
    quote do
      (fn raw -> unquote(body_expr) end).(Map.fetch!(map, unquote(name_atom)))
    end
  end

  defp wrap_nullable(name_atom, true, body_expr) do
    quote do
      case Map.get(map, unquote(name_atom)) do
        nil -> nil
        raw -> unquote(body_expr)
      end
    end
  end

  # ---------------------------------------------------------------------------
  # Variant private helpers
  # ---------------------------------------------------------------------------

  defp build_variant_defps(fields_with_nullable, registry, namespace) do
    fields_with_nullable
    |> Enum.filter(fn {field, _} -> field.type == "variant" end)
    |> Enum.flat_map(fn {field, _} -> variant_defp_pair(field, registry, namespace) end)
  end

  defp variant_defp_pair(%Field{} = field, _registry, namespace) do
    to_fn = to_variant_fn(field.name)
    from_fn = from_variant_fn(field.name)
    field_name_str = field.name

    # Build each case arm as a {:->, meta, [[pattern], body]} AST tuple directly,
    # because injecting dynamic clauses into a `case do` block via `unquote`
    # requires the clauses to be a flat list of `->` tuples.
    case_arms =
      Enum.map(field.variant_types, fn variant ->
        object_type = variant.object_type
        mod = Naming.ark_name_to_module(object_type, namespace)
        body = quote do: unquote(mod).from_map(Map.delete(v, :__ark_schema))
        {:->, [], [[object_type], body]}
      end)

    other_var = Macro.var(:other, nil)

    catch_body =
      quote do
        raise ArgumentError,
              "Unknown variant type in field #{unquote(field_name_str)}: #{inspect(unquote(other_var))}"
      end

    catch_arm = {:->, [], [[other_var], catch_body]}

    subject = quote do: ExArk.Types.get_type(v)
    case_expr = {:case, [], [subject, [do: case_arms ++ [catch_arm]]]}

    [
      quote do
        defp unquote(to_fn)(val) do
          schema_name = val.__struct__.__ark_schema_name()
          Map.put(val.__struct__.to_map(val), :__ark_schema, schema_name)
        end
      end,
      quote do
        defp unquote(from_fn)(v) do
          unquote(case_expr)
        end
      end
    ]
  end

  defp to_variant_fn(field_name), do: :"__to_variant_#{field_name}__"
  defp from_variant_fn(field_name), do: :"__from_variant_#{field_name}__"
end
