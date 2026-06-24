defmodule RbufViewerWeb.EditorLive do
  use RbufViewerWeb, :live_view

  alias ExArk.Ir.Schema
  alias RbufViewer.Ark
  alias RbufViewer.Downloads
  alias RbufViewer.Editor.Document

  @impl true
  def mount(_params, _session, socket) do
    socket =
      socket
      |> assign(:document, Document.blank())
      |> assign(:registry_path, nil)
      |> assign(:registry, nil)
      |> assign(:registry_choices, [])
      |> assign(:schema_search, "")
      |> assign(:mode, "generic")
      |> assign(:save_mode, "typed")
      |> assign(:status, nil)
      |> assign(:message, nil)
      |> allow_upload(:registry_file,
        accept: :any,
        max_entries: 1,
        max_file_size: 50_000_000,
        auto_upload: true,
        progress: &handle_upload_progress/3
      )
      |> allow_upload(:payload_file,
        accept: :any,
        max_entries: 1,
        max_file_size: 200_000_000,
        auto_upload: true,
        progress: &handle_upload_progress/3
      )

    {:ok, socket}
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div id="editor-live" class="workspace" phx-hook="DownloadManager">
      <header class="topbar">
        <div>
          <h1>Rbuf Viewer</h1>
          <p>Browse, edit, and reserialize Ark rbuf payloads.</p>
        </div>
        <div class="mode-switch">
          <button class={button_class(@mode == "generic")} phx-click="set_mode" phx-value-mode="generic">Generic</button>
          <button class={button_class(@mode == "typed")} phx-click="set_mode" phx-value-mode="typed">Typed</button>
          <button class={button_class(@mode == "new")} phx-click="set_mode" phx-value-mode="new">New RBuf</button>
        </div>
      </header>

      <section class="loadbar">
        <%= if @mode in ["typed", "new"] do %>
          <.form for={%{}} phx-change="validate_registry" multipart class="loader">
            <label>Registry</label>
            <.live_file_input upload={@uploads.registry_file} />
            <div class="upload-hint">Loads automatically when selected.</div>
            <%= for entry <- @uploads.registry_file.entries do %>
              <div class="upload-entry">
                <span><%= entry.client_name %></span>
                <button type="button" phx-click="cancel_upload" phx-value-upload="registry_file" phx-value-ref={entry.ref}>
                  Cancel
                </button>
              </div>
            <% end %>
          </.form>
        <% end %>

        <%= if @mode in ["typed", "new"] and @registry do %>
          <div class="loader schema-picker">
            <label>Search schemas</label>
            <.form for={%{}} phx-change="search_schemas" class="schema-search-form">
            <input
              name="schema_search"
              type="text"
              value={@schema_search}
              placeholder="Search schema names"
              autocomplete="new-password"
              autocapitalize="off"
              spellcheck="false"
            />
          </.form>

            <.form for={%{}} phx-change="choose_schema" class="schema-select-form">
              <label>Select schema</label>
              <select name="schema_name" size="10">
                <%= for name <- filtered_schema_choices(@registry_choices, @schema_search) do %>
                  <option value={name} selected={name == document_schema_name(@document)}><%= name %></option>
                <% end %>
              </select>
              <div class="upload-hint"><%= length(filtered_schema_choices(@registry_choices, @schema_search)) %> matches</div>
            </.form>
          </div>
        <% end %>

        <%= if @mode in ["generic", "typed"] do %>
          <.form for={%{}} phx-change="validate_payload" multipart class="loader">
            <label>Rbuf payload</label>
            <.live_file_input upload={@uploads.payload_file} disabled={@mode == "typed" and is_nil(@registry)} />
            <div class="upload-hint">
              <%= if @mode == "typed" and is_nil(@registry) do %>
                Load a registry first.
              <% else %>
                Loads automatically when selected.
              <% end %>
            </div>
            <%= for entry <- @uploads.payload_file.entries do %>
              <div class="upload-entry">
                <span><%= entry.client_name %></span>
                <button type="button" phx-click="cancel_upload" phx-value-upload="payload_file" phx-value-ref={entry.ref}>
                  Cancel
                </button>
              </div>
            <% end %>
          </.form>
        <% end %>

        <div class="actions">
          <div class="save-switch">
            <button class={save_button_class(@save_mode == "typed")} phx-click="save_and_download" phx-value-mode="typed">
              Save typed (.typed.rbuf)
            </button>
            <button class={save_button_class(@save_mode == "generic")} phx-click="save_and_download" phx-value-mode="generic">
              Save generic (.generic.rbuf)
            </button>
          </div>
          <div class="upload-hint">Clicking a save button downloads immediately using the browser's save flow.</div>
        </div>
      </section>

      <%= if @message do %>
        <div class="status"><%= @message %></div>
      <% end %>

      <section class="editor-shell">
        <%= if @document.schema do %>
          <div class="editor-head">
            <div class="editor-headline">
              <div class="schema-pill">Schema</div>
              <div>
                <h2><%= schema_label(@document.schema) %></h2>
              </div>
            </div>
            <div class="stats">
              <span><%= byte_size(document_bytes(@document) || <<>>) %> bytes</span>
              <span><%= map_size(Map.delete(document_object(@document) || %{}, :__ark_schema)) %> fields</span>
            </div>
          </div>

          <div class="editor-tree">
            <%= for field <- Document.schema_fields(@document.schema) do %>
              <.field_row
                document={@document}
                field={field}
                value={Map.get(document_object(@document) || %{}, String.to_atom(field.name))}
                path={[{:field, field.name}]}
                level={0}
              />
            <% end %>
          </div>
        <% else %>
          <div class="empty-state">
            <%= cond do %>
              <% @mode == "typed" -> %>
                Load a registry, then select a schema to create a draft or load a typed payload.
              <% @mode == "new" -> %>
                Load a registry, then select a schema to create an empty rbuf.
              <% true -> %>
                Load a payload or create a draft to start editing.
            <% end %>
          </div>
        <% end %>
      </section>
    </div>
    """
  end

  defp button_class(true), do: "mode-button active"
  defp button_class(false), do: "mode-button"

  defp schema_label(%Schema{} = schema), do: Schema.object_name(schema)
  defp schema_label(other), do: to_string(other)

  defp document_schema_name(%Document{schema_name: schema_name}), do: schema_name
  defp document_schema_name(%{schema_name: schema_name}), do: schema_name
  defp document_schema_name(_), do: nil

  defp document_bytes(%Document{bytes: bytes}), do: bytes
  defp document_bytes(%{bytes: bytes}), do: bytes
  defp document_bytes(_), do: nil

  defp document_object(%Document{object: object}), do: object
  defp document_object(%{object: object}), do: object
  defp document_object(_), do: nil

  defp path_token(path), do: Base.url_encode64(:erlang.term_to_binary(path), padding: false)
  defp decode_path(token), do: :erlang.binary_to_term(Base.url_decode64!(token, padding: false))

  defp path_crumbs([]), do: []

  defp path_crumbs(path) do
    Enum.map(path, fn
      {:field, name} -> name
      {:index, index} -> "[#{index}]"
      {:dict_entry, key} -> inspect(key)
    end)
  end

  defp field_label(%{name: name}) when is_binary(name), do: name
  defp field_label(%{object_type: object_type}) when is_binary(object_type), do: object_type
  defp field_label(%{type: type}), do: type

  defp field_hint(%{type: "object", object_type: object_type}) when is_binary(object_type),
    do: "object → #{object_type}"

  defp field_hint(%{type: "enum", object_type: object_type}) when is_binary(object_type),
    do: "enum → #{object_type}"

  defp field_hint(%{type: "variant", variant_types: variants}) when is_list(variants) do
    "variant → #{Enum.map_join(variants, ", ", & &1.object_type)}"
  end

  defp field_hint(%{type: "array", ctr_value_type: ctr_value_type}),
    do: "array of #{field_label(ctr_value_type)}"

  defp field_hint(%{type: "arraylist", ctr_value_type: ctr_value_type}),
    do: "arraylist of #{field_label(ctr_value_type)}"

  defp field_hint(%{
         type: "dictionary",
         ctr_key_type: ctr_key_type,
         ctr_value_type: ctr_value_type
       }),
       do: "dictionary #{field_label(ctr_key_type)} → #{field_label(ctr_value_type)}"

  defp field_hint(%{comments: comments}) when is_binary(comments), do: comments
  defp field_hint(_field), do: nil

  defp filtered_schema_choices(choices, ""), do: choices

  defp filtered_schema_choices(choices, query) when is_binary(query) do
    needle = String.downcase(query)

    Enum.filter(choices, fn choice ->
      String.contains?(String.downcase(choice), needle)
    end)
  end

  defp variant_options(%{variant_types: variants}, registry) do
    for variant <- variants do
      schema = Map.get(registry.schemas, variant.object_type)
      {variant.object_type, schema_label(schema || variant.object_type)}
    end
  end

  defp current_value(%{type: "array"} = field, value),
    do: value || List.duplicate(nil, field.array_size || 0)

  defp current_value(_field, value), do: value

  defp type_summary(%{type: "string"}, value), do: inspect(value || "")
  defp type_summary(%{type: "guid"}, value), do: inspect(value || "")

  defp type_summary(%{type: "byte_buffer"}, value) when is_binary(value),
    do: "#{byte_size(value)} bytes"

  defp type_summary(%{type: "bool"}, value), do: to_string(value)

  defp type_summary(%{type: t}, value)
       when t in ~w(uint8 uint16 uint32 uint64 int8 int16 int32 int64 float double),
       do: inspect(value)

  defp type_summary(%{type: "enum"}, value), do: inspect(value)

  defp type_summary(%{type: "object"}, value),
    do: inspect(Map.get(value || %{}, :__ark_schema, "object"))

  defp type_summary(%{type: "variant"}, value),
    do: inspect(Map.get(value || %{}, :__ark_schema, "variant"))

  defp type_summary(%{type: "array"}, value), do: "array(#{length(value || [])})"
  defp type_summary(%{type: "arraylist"}, value), do: "arraylist(#{length(value || [])})"
  defp type_summary(%{type: "dictionary"}, value), do: "dictionary(#{map_size(value || %{})})"
  defp type_summary(_field, value), do: inspect(value)

  attr(:document, :map, required: true)
  attr(:field, :map, required: true)
  attr(:value, :any, required: true)
  attr(:path, :list, required: true)
  attr(:level, :integer, required: true)

  def field_row(assigns) do
    field = assigns.field
    value = current_value(field, assigns.value)
    open? = Document.path_open?(assigns.document, assigns.path)
    path_token = path_token(assigns.path)
    crumbs = [document_schema_name(assigns.document) | path_crumbs(assigns.path)]

    base_assigns =
      assign(assigns,
        value: value,
        open?: open?,
        path_token: path_token,
        crumbs: crumbs
      )

    complex_content = if open?, do: render_complex(base_assigns), else: nil

    assigns =
      assign(base_assigns,
        value: value,
        open?: open?,
        summary: type_summary(field, value),
        complex_content: complex_content
      )

    ~H"""
    <div class={"field-row level-#{@level}"}>
      <div class="field-crumbs">
        <%= for {crumb, index} <- Enum.with_index(@crumbs) do %>
          <span :if={index > 0} class="crumb-separator">/</span>
          <span class={["crumb-pill", index == 0 && "crumb-root"]}><%= crumb %></span>
        <% end %>
      </div>

      <div class="field-head">
        <div class="field-title">
          <span class="field-name"><%= field_label(@field) %></span>
          <span class="field-type"><%= @field.type %></span>
        </div>
        <div class="field-actions">
          <%= if complex_type?(@field.type) do %>
            <button phx-click="toggle_path" phx-value-path={@path_token}>
              <%= if @open?, do: "Collapse", else: "Expand" %>
            </button>
          <% end %>
        </div>
      </div>

      <div class="field-body">
        <%= if field_hint(@field) do %>
          <div class="field-hint"><%= field_hint(@field) %></div>
        <% end %>
        <%= if primitive_type?(@field.type) do %>
          <.primitive_editor document={@document} field={@field} value={@value} path={@path} />
        <% else %>
          <div class="field-summary"><%= @summary %></div>
        <% end %>
      </div>

      <%= if @open? do %>
        <div class="field-expanded">
          <%= @complex_content %>
        </div>
      <% end %>
    </div>
    """
  end

  attr(:document, :map, required: true)
  attr(:field, :map, required: true)
  attr(:value, :any, required: true)
  attr(:path, :list, required: true)

  def primitive_editor(assigns) do
    field = assigns.field
    path_token = path_token(assigns.path)

    assigns =
      assign(assigns,
        path_token: path_token,
        editor_value: primitive_editor_value(field, assigns.value)
      )

    ~H"""
    <form phx-submit="set_value" class="primitive-form">
      <input type="hidden" name="path" value={@path_token} />
      <input type="hidden" name="field_type" value={@field.type} />

      <%= case @field.type do %>
        <% "bool" -> %>
          <select name="value">
            <option value="false" selected={!@editor_value}>false</option>
            <option value="true" selected={@editor_value}>true</option>
          </select>
        <% "enum" -> %>
          <%= enum_editor(assigns) %>
        <% "byte_buffer" -> %>
          <textarea name="value" rows="4"><%= @editor_value %></textarea>
        <% _ -> %>
          <input name="value" value={@editor_value} />
      <% end %>

      <button type="submit">Apply</button>
    </form>
    """
  end

  defp primitive_editor_value(%{type: "byte_buffer"}, value) when is_binary(value) do
    value |> Base.encode16(case: :lower) |> chunk_hex()
  end

  defp primitive_editor_value(%{type: "bool"}, value), do: if(value, do: "true", else: "false")

  defp primitive_editor_value(%{type: t}, value)
       when t in ~w(uint8 uint16 uint32 uint64 int8 int16 int32 int64 float double string guid),
       do: to_string(value || "")

  defp primitive_editor_value(%{type: "enum"}, value) when is_list(value),
    do: Enum.map_join(value, ",", &to_string/1)

  defp primitive_editor_value(_field, value), do: to_string(value || "")

  defp chunk_hex(hex) do
    hex
    |> String.graphemes()
    |> Enum.chunk_every(2)
    |> Enum.map_join(" ", &Enum.join/1)
  end

  defp enum_editor(assigns) do
    enum = Map.fetch!(assigns.document.registry.enums, assigns.field.object_type)
    options = Map.keys(enum.values)

    assigns = assign(assigns, enum: enum, options: options)

    ~H"""
    <%= if @enum.enum_type == :value do %>
      <select name="value">
        <%= for option <- @options do %>
          <option value={Atom.to_string(option)} selected={option == @value}><%= option %></option>
        <% end %>
      </select>
    <% else %>
      <select name="value[]" multiple size={min(length(@options), 8)}>
        <%= for option <- @options do %>
          <option value={Atom.to_string(option)} selected={option in List.wrap(@value)}><%= option %></option>
        <% end %>
      </select>
    <% end %>
    """
  end

  defp render_complex(assigns) do
    case assigns.field.type do
      "object" -> object_body(assigns)
      "variant" -> variant_body(assigns)
      "array" -> collection_body(assigns)
      "arraylist" -> collection_body(assigns)
      "dictionary" -> dictionary_body(assigns)
      _ -> nil
    end
  end

  defp object_body(assigns) do
    schema = Map.fetch!(assigns.document.registry.schemas, assigns.field.object_type)
    assigns = assign(assigns, schema: schema, schema_label: Schema.object_name(schema))

    ~H"""
    <div class="schema-scope">
      <div class="scope-pill">Object</div>
      <div class="scope-title"><%= @schema_label %></div>
      <div class="scope-meta"><%= field_label(@field) %></div>
    </div>

    <div class="object-children">
      <%= for child <- Document.schema_fields(@schema) do %>
        <.field_row
          document={@document}
          field={child}
          value={Map.get(@value, String.to_atom(child.name))}
          path={@path ++ [{:field, child.name}]}
          level={@level + 1}
        />
      <% end %>
    </div>
    """
  end

  defp variant_body(assigns) do
    selected = Map.get(assigns.value || %{}, :__ark_schema)
    options = variant_options(assigns.field, assigns.document.registry)

    selected_label =
      case Enum.find(options, fn {value, _label} -> value == selected end) do
        {_, label} -> label
        nil -> "unset"
      end

    assigns =
      assign(assigns,
        selected: selected,
        selected_label: selected_label,
        options: options
      )

    ~H"""
      <div class="schema-scope">
        <div class="scope-pill">Variant</div>
        <div class="scope-title"><%= field_label(@field) %></div>
        <div class="scope-meta"><%= @selected_label %></div>
      </div>

      <div class="variant-picker">
        <form phx-change="set_variant" class="primitive-form variant-form">
          <input type="hidden" name="path" value={@path_token} />
          <select name="schema_name">
          <%= for {value, label} <- @options do %>
            <option value={value} selected={value == @selected}><%= label %></option>
          <% end %>
          </select>
        </form>

      <%= if @selected do %>
        <% schema = Map.fetch!(@document.registry.schemas, @selected) %>
        <%= for child <- Document.schema_fields(schema) do %>
          <.field_row
            document={@document}
            value={Map.get(@value, String.to_atom(child.name))}
            field={child}
            path={@path ++ [{:field, child.name}]}
            level={@level + 1}
          />
        <% end %>
      <% end %>
    </div>
    """
  end

  defp collection_body(assigns) do
    assigns = assign(assigns, value: List.wrap(assigns.value || []))

    ~H"""
    <div class="collection-toolbar">
      <button phx-click="clear_collection" phx-value-path={@path_token}>Clear</button>
      <%= if @field.type == "arraylist" do %>
        <button phx-click="add_item" phx-value-path={@path_token}>Add item</button>
      <% end %>
    </div>

    <div class="collection-items">
      <%= for {item, index} <- Enum.with_index(@value) do %>
        <.collection_item
          document={@document}
          field={@field.ctr_value_type}
          value={item}
          path={@path ++ [{:index, index}]}
          index={index}
          level={@level + 1}
          collection_type={@field.type}
        />
      <% end %>
    </div>
    """
  end

  defp dictionary_body(assigns) do
    entries =
      Map.to_list(assigns.value || %{}) |> Enum.sort_by(fn {key, _value} -> inspect(key) end)

    assigns = assign(assigns, entries: entries)

    ~H"""
    <div class="collection-toolbar">
      <button phx-click="clear_collection" phx-value-path={@path_token}>Clear</button>
      <button phx-click="add_item" phx-value-path={@path_token}>Add entry</button>
    </div>

    <div class="collection-items">
      <%= for {key, item} <- @entries do %>
        <.dictionary_item
          document={@document}
          field={@field.ctr_value_type}
          value={item}
          key={key}
          path={@path ++ [{:dict_entry, key}]}
          level={@level + 1}
        />
      <% end %>
    </div>
    """
  end

  attr(:document, :map, required: true)
  attr(:field, :map, required: true)
  attr(:value, :any, required: true)
  attr(:path, :list, required: true)
  attr(:index, :integer, required: true)
  attr(:level, :integer, required: true)
  attr(:collection_type, :string, required: true)

  def collection_item(assigns) do
    open? = Document.path_open?(assigns.document, assigns.path)

    assigns =
      assign(assigns,
        open?: open?,
        path_token: path_token(assigns.path),
        crumbs: [document_schema_name(assigns.document) | path_crumbs(assigns.path)]
      )

    ~H"""
    <div class={"item-row level-#{@level}"}>
      <div class="field-crumbs">
        <%= for {crumb, index} <- Enum.with_index(@crumbs) do %>
          <span :if={index > 0} class="crumb-separator">/</span>
          <span class={["crumb-pill", index == 0 && "crumb-root"]}><%= crumb %></span>
        <% end %>
      </div>

      <div class="field-head">
        <div class="field-title">
          <span class="field-name">Item <%= @index %></span>
          <span class="field-type"><%= @field.type %></span>
        </div>
        <div class="field-actions">
          <button phx-click="toggle_path" phx-value-path={@path_token}>
            <%= if @open?, do: "Collapse", else: "Expand" %>
          </button>
          <button phx-click="reset_item" phx-value-path={@path_token}>Reset</button>
          <%= if @collection_type == "arraylist" do %>
            <button phx-click="remove_item" phx-value-path={@path_token}>Remove</button>
          <% end %>
        </div>
      </div>

      <div class="field-summary"><%= type_summary(@field, @value) %></div>

      <%= if @open? do %>
        <div class="field-expanded">
          <.field_row
            document={@document}
            field={@field}
            value={@value}
            path={@path}
            level={@level}
          />
        </div>
      <% end %>
    </div>
    """
  end

  attr(:document, :map, required: true)
  attr(:field, :map, required: true)
  attr(:value, :any, required: true)
  attr(:key, :any, required: true)
  attr(:path, :list, required: true)
  attr(:level, :integer, required: true)

  def dictionary_item(assigns) do
    open? = Document.path_open?(assigns.document, assigns.path)

    assigns =
      assign(assigns,
        open?: open?,
        path_token: path_token(assigns.path),
        crumbs: [document_schema_name(assigns.document) | path_crumbs(assigns.path)]
      )

    ~H"""
    <div class={"dictionary-row level-#{@level}"}>
      <div class="field-crumbs">
        <%= for {crumb, index} <- Enum.with_index(@crumbs) do %>
          <span :if={index > 0} class="crumb-separator">/</span>
          <span class={["crumb-pill", index == 0 && "crumb-root"]}><%= crumb %></span>
        <% end %>
      </div>

      <div class="field-head">
        <div class="field-title">
          <span class="field-name">Key: <%= inspect(@key) %></span>
          <span class="field-type">dictionary</span>
        </div>
        <div class="field-actions">
          <button phx-click="toggle_path" phx-value-path={@path_token}>
            <%= if @open?, do: "Collapse value", else: "Open value" %>
          </button>
          <button phx-click="remove_item" phx-value-path={@path_token}>Remove</button>
        </div>
      </div>

      <div class="field-summary"><%= type_summary(@field, @value) %></div>

      <%= if @open? do %>
        <div class="field-expanded">
          <.field_row
            document={@document}
            field={@field}
            value={@value}
            path={@path}
            level={@level}
          />
        </div>
      <% end %>
    </div>
    """
  end

  defp primitive_type?(type),
    do:
      type in ~w(bool uint8 uint16 uint32 uint64 int8 int16 int32 int64 float double string guid byte_buffer)

  defp complex_type?(type), do: type in ~w(array arraylist dictionary object variant enum)

  defp save_button_class(true), do: "mode-button active"
  defp save_button_class(false), do: "mode-button"

  @impl true
  def handle_event("set_mode", %{"mode" => mode}, socket) do
    {:noreply,
     socket
     |> assign(:mode, mode)
     |> assign(:document, Document.blank())
     |> assign(:save_mode, if(mode == "generic", do: "generic", else: "typed"))
     |> assign(:schema_search, "")
     |> assign(:message, nil)}
  end

  def handle_event("validate_registry", _params, socket), do: {:noreply, socket}

  def handle_event("validate_payload", _params, socket), do: {:noreply, socket}

  def handle_event("search_schemas", %{"schema_search" => schema_search}, socket) do
    {:noreply, assign(socket, :schema_search, schema_search)}
  end

  def handle_event("cancel_upload", %{"upload" => upload, "ref" => ref}, socket) do
    name = String.to_existing_atom(upload)
    {:noreply, cancel_upload(socket, name, ref)}
  end

  def handle_event("choose_schema", %{"schema_name" => schema_name}, socket) do
    case socket.assigns.mode do
      "new" ->
        case socket.assigns.registry do
          %ExArk.Registry{} = registry ->
            document = Document.from_schema(registry, schema_name)

            {:noreply,
             socket
             |> assign(:document, document)
             |> assign(:save_mode, "typed")
             |> assign(:message, "Draft created")}

          _ ->
            {:noreply, assign(socket, :message, "Load a registry first")}
        end

      "typed" ->
        document = socket.assigns.document

        case {socket.assigns.registry, document.bytes} do
          {%ExArk.Registry{} = registry, bytes} when is_binary(bytes) ->
            case Ark.load_typed_bytes(registry, schema_name, bytes) do
              {:ok, payload} ->
                {:noreply,
                 socket
                 |> assign(:document, Document.from_loaded(payload))
                 |> assign(:message, "Typed schema loaded")}

              {:error, reason} ->
                {:noreply, assign(socket, :message, "Schema load failed: #{inspect(reason)}")}
            end

          _ ->
            {:noreply, assign(socket, document: %{document | schema_name: schema_name})}
        end

      _ ->
        {:noreply, socket}
    end
  end

  def handle_event("toggle_path", %{"path" => path_token}, socket) do
    path = decode_path(path_token)
    document = Document.toggle_path(socket.assigns.document, path)
    {:noreply, assign(socket, :document, document)}
  end

  def handle_event("set_value", params, socket) do
    path = decode_path(params["path"])
    raw_value = Map.get(params, "value", Map.get(params, "value[]", ""))

    case Document.update_value(socket.assigns.document, path, raw_value) do
      {:ok, document} ->
        {:noreply, assign(socket, :document, document)}

      {:error, reason} ->
        {:noreply, assign(socket, :message, "Update failed: #{inspect(reason)}")}
    end
  end

  def handle_event("set_variant", %{"path" => path_token, "schema_name" => schema_name}, socket) do
    path = decode_path(path_token)

    case Document.set_variant_type(socket.assigns.document, path, schema_name) do
      {:ok, document} ->
        {:noreply, assign(socket, :document, document)}

      {:error, reason} ->
        {:noreply, assign(socket, :message, "Variant failed: #{inspect(reason)}")}
    end
  end

  def handle_event("clear_collection", %{"path" => path_token}, socket) do
    path = decode_path(path_token)

    case Document.clear_collection(socket.assigns.document, path) do
      {:ok, document} -> {:noreply, assign(socket, :document, document)}
      {:error, reason} -> {:noreply, assign(socket, :message, "Clear failed: #{inspect(reason)}")}
    end
  end

  def handle_event("add_item", %{"path" => path_token}, socket) do
    path = decode_path(path_token)

    case Document.add_item(socket.assigns.document, path) do
      {:ok, document} -> {:noreply, assign(socket, :document, document)}
      {:error, reason} -> {:noreply, assign(socket, :message, "Add failed: #{inspect(reason)}")}
    end
  end

  def handle_event("remove_item", %{"path" => path_token}, socket) do
    path = decode_path(path_token)

    case Document.remove_item(socket.assigns.document, path) do
      {:ok, document} ->
        {:noreply, assign(socket, :document, document)}

      {:error, reason} ->
        {:noreply, assign(socket, :message, "Remove failed: #{inspect(reason)}")}
    end
  end

  def handle_event("reset_item", %{"path" => path_token}, socket) do
    path = decode_path(path_token)

    case Document.reset_item(socket.assigns.document, path) do
      {:ok, document} -> {:noreply, assign(socket, :document, document)}
      {:error, reason} -> {:noreply, assign(socket, :message, "Reset failed: #{inspect(reason)}")}
    end
  end

  def handle_event("save_and_download", %{"mode" => mode}, socket) do
    case Ark.save(
           %{
             mode: mode,
             registry: socket.assigns.document.registry,
             schema_name: document_schema_name(socket.assigns.document),
             object: socket.assigns.document.object
           },
           mode
         ) do
      {:ok, bytes} ->
        token =
          Downloads.put(
            bytes,
            Document.download_name(document_schema_name(socket.assigns.document), mode)
          )

        {:noreply,
         socket
         |> assign(:save_mode, mode)
         |> assign(:message, "Saved as #{mode} and downloaded")
         |> push_event("download-file", %{url: ~p"/downloads/#{token}"})}

      {:error, reason} ->
        {:noreply, assign(socket, :message, "Save failed: #{inspect(reason)}")}
    end
  end

  defp load_payload(bytes, socket) do
    case socket.assigns.mode do
      "generic" ->
        case Ark.load_generic_bytes(bytes) do
          {:ok, payload} ->
            document = Document.from_loaded(payload)

            {:noreply,
             assign(socket,
               document: document,
               registry: payload.registry,
               registry_choices: payload.registry.schemas |> Map.keys() |> Enum.sort(),
               schema_search: "",
               save_mode: "generic",
               message: "Generic payload loaded"
             )}

          {:error, reason} ->
            {:noreply, assign(socket, :message, "Payload error: #{inspect(reason)}")}
        end

      "typed" ->
        case socket.assigns.registry do
          %ExArk.Registry{} = registry ->
            schema_name =
              document_schema_name(socket.assigns.document) || Map.keys(registry.schemas) |> List.first()

            case Ark.load_typed_bytes(registry, schema_name, bytes) do
              {:ok, payload} ->
                document = Document.from_loaded(payload)

                {:noreply,
                 assign(socket,
                   document: document,
                   schema_search: "",
                   save_mode: "typed",
                   message: "Typed payload loaded"
                 )}

              {:error, reason} ->
                {:noreply, assign(socket, :message, "Payload error: #{inspect(reason)}")}
            end

          _ ->
            {:noreply, assign(socket, :message, "Load a registry first")}
        end
    end
  end

  def handle_upload_progress(:registry_file, entry, socket) do
    if entry.done? do
      case consume_uploaded_entry(socket, entry, fn %{path: path} ->
             File.read(path)
           end) do
        bytes when is_binary(bytes) ->
          case ExArk.Registry.build(bytes) do
            {:ok, registry} ->
              choices = registry.schemas |> Map.keys() |> Enum.sort()
              selected = document_schema_name(socket.assigns.document) || List.first(choices)

              {:noreply,
               socket
               |> assign(:registry, registry)
               |> assign(:registry_choices, choices)
               |> assign(:schema_search, "")
               |> assign(:document, %{socket.assigns.document | schema_name: selected})
               |> assign(:message, "Registry loaded")}

            {:error, reason} ->
              {:noreply, assign(socket, :message, "Registry error: #{inspect(reason)}")}
          end

        {:error, reason} ->
          {:noreply, assign(socket, :message, "Registry error: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end

  def handle_upload_progress(:payload_file, entry, socket) do
    if entry.done? do
      case consume_uploaded_entry(socket, entry, fn %{path: path} ->
             File.read(path)
           end) do
        bytes when is_binary(bytes) ->
          load_payload(bytes, socket)

        {:error, reason} ->
          {:noreply, assign(socket, :message, "Payload error: #{inspect(reason)}")}
      end
    else
      {:noreply, socket}
    end
  end
end
