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
  in prose or a Markdown list. For variant fields this returns the full union
  type string; use `fields_table/3` for a table-friendly rendering.
  """
  @spec field_type_string(Field.t(), Registry.t(), module()) :: String.t()
  def field_type_string(field, registry, namespace) do
    field_type_string_inner(field, registry, namespace)
  end

  # ---------------------------------------------------------------------------
  # Private helpers — fields table
  # ---------------------------------------------------------------------------

  defp fields_table(%Schema{} = schema, registry, namespace) do
    regular = schema.fields |> Enum.reject(&Field.removed?/1)

    group =
      schema.groups
      |> Enum.flat_map(& &1.fields)
      |> Enum.reject(&Field.removed?/1)

    all_fields = regular ++ group

    if all_fields == [] do
      "*(no fields)*"
    else
      table = build_fields_table(regular, group, registry, namespace)
      details = build_field_details_section(all_fields, registry, namespace)

      if details == "" do
        table
      else
        table <> "\n\n" <> details
      end
    end
  end

  defp build_fields_table(regular, group, registry, namespace) do
    regular_rows =
      Enum.map(regular, fn field ->
        type_cell = table_type_cell(field, registry, namespace)
        notes = field_notes(Field.optional?(field), "")
        "| `#{field.name}` | #{type_cell} | #{notes} |"
      end)

    group_rows =
      Enum.map(group, fn field ->
        type_cell = table_type_cell(field, registry, namespace)
        notes = field_notes(true, " (group)")
        "| `#{field.name}` | #{type_cell} | #{notes} |"
      end)

    header = "## Fields\n\n| Field | Type | Notes |\n|-------|------|-------|"
    Enum.join([header | regular_rows ++ group_rows], "\n")
  end

  # Variant types are listed in a dedicated sub-section so the Type column
  # stays narrow regardless of how many variant types a field has.
  defp table_type_cell(%Field{type: "variant"}, _registry, _namespace), do: "variant"
  defp table_type_cell(field, registry, namespace), do: field_type_string_inner(field, registry, namespace)

  defp field_notes(true, suffix), do: "optional#{suffix}"
  defp field_notes(false, _suffix), do: "required"

  # Builds the "## Field Details" section below the table. A field gets a
  # sub-section when it has a comment, is a variant (type list), or both.
  # Returns "" when no field needs extra detail.
  defp build_field_details_section(fields, registry, namespace) do
    blocks =
      fields
      |> Enum.map(&field_detail_block(&1, registry, namespace))
      |> Enum.reject(&is_nil/1)

    if blocks == [] do
      ""
    else
      "## Field Details\n\n" <> Enum.join(blocks, "\n\n")
    end
  end

  # Returns a detail block for a field, or nil if none is needed.
  defp field_detail_block(%Field{type: "variant"} = field, registry, namespace) do
    items =
      Enum.map(field.variant_types, fn v ->
        if Map.has_key?(registry.schemas, v.object_type) do
          mod = Naming.ark_name_to_module(v.object_type, namespace)
          "- `#{inspect(mod)}`"
        else
          "- `#{v.object_type}`"
        end
      end)

    ["### `#{field.name}` (variant)", format_comment(field.comments), "One of:\n" <> Enum.join(items, "\n")]
    |> Enum.reject(&is_nil/1)
    |> Enum.join("\n\n")
  end

  defp field_detail_block(%Field{comments: c}, _registry, _namespace) when c in [nil, ""] do
    nil
  end

  defp field_detail_block(%Field{} = field, _registry, _namespace) do
    "### `#{field.name}`\n\n#{format_comment(field.comments)}"
  end

  # Normalises a comment string for Markdown prose output:
  #   - trims trailing whitespace from each line
  #   - joins lines with a Markdown hard line break (two trailing spaces + \n)
  #     so that multi-line comments render as distinct lines in both ExDoc and IEx
  defp format_comment(nil), do: nil
  defp format_comment(""), do: nil

  defp format_comment(comment) do
    comment
    |> String.split("\n")
    |> Enum.map_join("  \n", &String.trim_trailing/1)
  end

  # ---------------------------------------------------------------------------
  # Private helpers — values table
  # ---------------------------------------------------------------------------

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

  # ---------------------------------------------------------------------------
  # Private helpers — field type descriptions
  # ---------------------------------------------------------------------------

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

    Enum.join(type_strs, " | ")
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
