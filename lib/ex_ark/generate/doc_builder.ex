defmodule ExArk.Generate.DocBuilder do
  @moduledoc """
  Builds `@moduledoc`, `@typedoc`, and `@doc` strings for generated modules.

  All functions in this module are called at macro-expansion time and return
  plain strings that are embedded as compile-time constants in the generated
  code, so `h/1` in IEx and ExDoc both pick them up automatically.
  """

  alias ExArk.Generate.Naming
  alias ExArk.Ir.ArkEnum
  alias ExArk.Ir.Field
  alias ExArk.Ir.Schema
  alias ExArk.Registry

  # ---------------------------------------------------------------------------
  # Public API
  # ---------------------------------------------------------------------------

  @doc """
  Builds the `@moduledoc` string for a generated schema module.
  """
  @spec schema_moduledoc(Schema.t(), Registry.t(), module()) :: String.t()
  def schema_moduledoc(%Schema{} = schema, %Registry{} = registry, namespace) do
    ark_name = Schema.object_name(schema)
    attrs_note = if Schema.final?(schema), do: "\n\n> This schema is **final** (no optional groups).", else: ""

    fields_md = fields_table(schema, registry, namespace)

    """
    Generated from Ark schema `#{ark_name}`.#{attrs_note}

    #{fields_md}
    """
    |> String.trim()
  end

  @doc """
  Builds the `@moduledoc` string for a generated enum module.
  """
  @spec enum_moduledoc(ArkEnum.t(), module()) :: String.t()
  def enum_moduledoc(%ArkEnum{} = enum, _namespace) do
    ark_name = ArkEnum.object_name(enum)
    class = to_string(enum.enum_class)
    style = to_string(enum.enum_type)

    values_md = values_table(enum)

    """
    Generated from Ark enum `#{ark_name}`.

    Underlying type: `#{class}` (#{style} enum).

    #{values_md}
    """
    |> String.trim()
  end

  @doc """
  Returns a human-readable type description for a field, suitable for embedding
  in a Markdown table cell. Pipe characters are escaped as `\\|`.
  """
  @spec field_type_string(Field.t(), Registry.t(), module()) :: String.t()
  def field_type_string(field, registry, namespace) do
    field_type_string_inner(field, registry, namespace)
  end

  defp fields_table(%Schema{} = schema, registry, namespace) do
    regular_rows =
      schema.fields
      |> Enum.reject(&Field.removed?/1)
      |> Enum.map(fn field ->
        notes = if Field.optional?(field), do: "optional", else: "required"
        "| `#{field.name}` | #{field_type_string_inner(field, registry, namespace)} | #{notes} |"
      end)

    group_rows =
      Enum.flat_map(schema.groups, fn group ->
        group.fields
        |> Enum.reject(&Field.removed?/1)
        |> Enum.map(fn field ->
          type_str = field_type_string_inner(field, registry, namespace)
          "| `#{field.name}` | #{type_str} | optional (group) |"
        end)
      end)

    all_rows = regular_rows ++ group_rows

    if all_rows == [] do
      "*(no fields)*"
    else
      header = "## Fields\n\n| Field | Type | Notes |\n|-------|------|-------|"
      Enum.join([header | all_rows], "\n")
    end
  end

  defp values_table(%ArkEnum{values: values}) when values == [] or values == %{} do
    "*(no values)*"
  end

  defp values_table(%ArkEnum{} = enum) do
    rows =
      enum.values
      |> Enum.sort_by(fn {_k, v} -> v end)
      |> Enum.map(fn {k, v} -> "| `#{inspect(k)}` | `#{v}` |" end)

    header = "## Values\n\n| Value | Integer |\n|-------|---------|"
    Enum.join([header | rows], "\n")
  end

  @primitives ~w(bool uint8 uint16 uint32 uint64 int8 int16 int32 int64
                 float double string guid byte_buffer duration
                 steady_time_point system_time_point)

  defp field_type_string_inner(%Field{type: t}, _registry, _namespace) when t in @primitives do
    "`#{t}`"
  end

  defp field_type_string_inner(
         %Field{type: "object", object_type: object_type},
         registry,
         namespace
       ) do
    if Map.has_key?(registry.schemas, object_type) do
      mod = Naming.ark_name_to_module(object_type, namespace)
      "`#{inspect(mod)}`"
    else
      "`#{object_type}`"
    end
  end

  defp field_type_string_inner(
         %Field{type: "enum", object_type: object_type},
         registry,
         namespace
       ) do
    if Map.has_key?(registry.enums, object_type) do
      mod = Naming.ark_name_to_module(object_type, namespace)
      "`#{inspect(mod)}`"
    else
      "`#{object_type}`"
    end
  end

  defp field_type_string_inner(
         %Field{type: "variant", variant_types: variants},
         registry,
         namespace
       ) do
    type_strs =
      Enum.map(variants, fn v ->
        if Map.has_key?(registry.schemas, v.object_type) do
          mod = Naming.ark_name_to_module(v.object_type, namespace)
          "`#{inspect(mod)}.t()`"
        else
          "`#{v.object_type}`"
        end
      end)

    # Escape | so it doesn't break the Markdown table cell.
    Enum.join(type_strs, " \\| ")
  end

  defp field_type_string_inner(
         %Field{type: t, ctr_value_type: vt},
         registry,
         namespace
       )
       when t in ["array", "arraylist"] do
    inner = field_type_string_inner(vt, registry, namespace)
    "list(#{inner})"
  end

  defp field_type_string_inner(
         %Field{type: "dictionary", ctr_key_type: kt, ctr_value_type: vt},
         registry,
         namespace
       ) do
    key_str = field_type_string_inner(kt, registry, namespace)
    val_str = field_type_string_inner(vt, registry, namespace)
    "%{#{key_str} => #{val_str}}"
  end

  defp field_type_string_inner(%Field{type: t}, _registry, _namespace), do: "`#{t}`"
end
