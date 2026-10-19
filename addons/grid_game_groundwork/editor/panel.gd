@tool
class_name GGEditorPanel
extends VBoxContainer

var authoring = GGLevelAuthoring.new()
var selection = GGEditorSelection.new(authoring)
var stroke = GGEditorStroke.new(authoring)
var viewport: GGEditorViewport
var _palette: ItemList
var _status: Label
var _title: Label
var _mode = 0
var _level_mode = 0
var _tool_buttons: Array[Button] = []
var _brush_controls: HBoxContainer
var _brush_label: Label
var _hint: Label
var _pointer_status: Label
var _shape_banner: HBoxContainer
var _shape_label: Label
var _definition_label: Label
var _definition_buttons: Array[Button] = []
var _tabs: TabContainer
var _single_entity: VBoxContainer
var _selection_actions: HBoxContainer
var _duplicate_button: Button
var _delete_button: Button
var _play_button: Button
var _stop_button: Button
var _floor_height: SpinBox
var _floor_button: Button
var _floor_hint: Label
var _status_detail: AcceptDialog
var _status_text: RichTextLabel
var _help: AcceptDialog
var _help_text: RichTextLabel
var _icon_buttons: Dictionary = {}
var _muted_labels: Array[Label] = []
var _heading_labels: Array[Label] = []
var _scale = 1.0
var _height: SpinBox
var _turns: SpinBox
var _mirror: CheckBox
var _shape_mode: CheckButton
var _apply_button: Button
var _reset_button: Button
var _definition: GGEntityDefinition
var _coords: Array[SpinBox] = []
var _entity_turns: SpinBox
var _entity_mirror: CheckBox
var _entity_label: Label
var _overrides = GGPropertyOverrides.new()
var _inspector: EditorInspector
var _settings_title: LineEdit
var _gravity: CheckBox
var _void: SpinBox
var _rule_picker: EditorResourcePicker
var _floor_width: SpinBox
var _floor_depth: SpinBox
var _pending: Callable
var _confirm: ConfirmationDialog
var _file: EditorFileDialog
var _file_action: String
var _last_hover = Vector3i.ZERO
var _updating = false
var _definition_refresh_pending = false

func _ready() -> void:
	_scale = EditorInterface.get_editor_scale()
	add_theme_constant_override("separation", int(8 * _scale))
	_build_header()
	_build_tools()
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	_build_palette(_scroll_column(split, 200))
	var center_right = HSplitContainer.new()
	center_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(center_right)
	var center = _column(center_right)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	viewport = GGEditorViewport.new()
	viewport.selection = selection
	viewport.stroke = stroke
	center.add_child(viewport)
	viewport.custom_minimum_size = Vector2(260, 280) * _scale
	viewport.entity_picked.connect(_pick_entity)
	viewport.hovered.connect(_hover)
	viewport.layer_changed.connect(_paint_height_changed)
	viewport.selection_height_requested.connect(_move_selection_height)
	var hint_row = _row(center)
	_hint = _line_label(hint_row)
	_muted_labels.append(_hint)
	_button(hint_row, "Help", func(): _popup_text_dialog(_help, Vector2(600, 520)), "Help", "Camera controls and all keyboard shortcuts")
	_tabs = TabContainer.new()
	_tabs.custom_minimum_size.x = 280 * _scale
	_tabs.use_hidden_tabs_for_min_size = false
	center_right.add_child(_tabs)
	var selected = _scroll_column(_tabs, 0)
	selected.get_parent().name = "Selected entity"
	_build_selection(selected)
	var level = _scroll_column(_tabs, 0)
	level.get_parent().name = "Level"
	_build_level_settings(level)
	_build_status()
	_build_help()
	_file = EditorFileDialog.new()
	_file.add_filter("*.tres", "Godot resources")
	_file.file_selected.connect(_file_selected)
	add_child(_file)
	_confirm = ConfirmationDialog.new()
	_confirm.dialog_text = "Discard unsaved edits to this level? Save first to keep them."
	_confirm.ok_button_text = "Discard and continue"
	_confirm.confirmed.connect(func():
		if authoring.discard_changes():
			if _pending.is_valid(): _pending.call()
		else:
			_set_status(authoring.last_error)
	)
	add_child(_confirm)
	_turns.value_changed.connect(func(_value): _configure_stroke())
	_mirror.toggled.connect(func(_value): _configure_stroke())
	selection.changed.connect(_update_selection)
	selection.preview_changed.connect(_sync_coordinates)
	selection.feedback.connect(_set_status)
	authoring.changed.connect(_refresh)
	EditorInterface.get_inspector().property_edited.connect(_inspector_property_edited)
	EditorInterface.get_base_control().theme_changed.connect(_refresh_theme)
	_refresh_theme()
	_new_level()

func _build_header() -> void:
	var header = _flow(self)
	_title = _line_label(header)
	_title.custom_minimum_size.x = 150 * _scale
	var files = _row(header)
	var menu = MenuButton.new()
	menu.text = "File"
	menu.tooltip_text = "New, open, or save a copy of a level"
	files.add_child(menu)
	menu.get_popup().add_item("New level", 0)
	menu.get_popup().add_item("Open…", 1)
	menu.get_popup().add_separator()
	menu.get_popup().add_item("Save as…", 2)
	menu.get_popup().id_pressed.connect(func(id):
		match id:
			0: _guard(_new_level)
			1: _guard(func(): _dialog("open_level"))
			2: _dialog("save_level")
	)
	_button(files, "Save", save_current, "Save", "Save level and shared configuration (Ctrl/Cmd+S)")
	var play = _row(header)
	_play_button = _button(play, "Playtest", _playtest, "Play", "Test a temporary copy, including unsaved edits")
	_stop_button = _button(play, "Stop", func(): EditorInterface.stop_playing_scene(), "Stop", "Stop the running scene")
	_stop_button.disabled = true
	var timer = Timer.new()
	timer.wait_time = 0.25
	timer.autostart = true
	timer.timeout.connect(_sync_play_state)
	add_child(timer)

func _build_tools() -> void:
	var toolbar = _flow(self)
	var tools = _row(toolbar)
	var group = ButtonGroup.new()
	var names = ["Paint (1)", "Erase (2)", "Select (3)"]
	var icons = ["Edit", "Eraser", "ToolSelect"]
	for index in range(3):
		var button = _button(tools, names[index], _set_mode.bind(index), icons[index])
		button.toggle_mode = true
		button.button_group = group
		_tool_buttons.append(button)
	var history = _row(toolbar)
	_button(history, "Undo", authoring.undo, "Undo", "Undo authoring edit (Ctrl/Cmd+Z)")
	_button(history, "Redo", authoring.redo, "Redo", "Redo authoring edit (Ctrl/Cmd+Shift+Z / Ctrl/Cmd+Y)")
	var view_tools = _row(toolbar)
	_button(view_tools, "Frame", func(): viewport.frame_level(), "ZoomMore", "Frame the whole level (F)")
	_button(view_tools, "Validate", _validate, "StatusSuccess", "Check definitions, occupied cells, and level configuration")
	var context = _flow(self)
	_height = _spin(context, "Height", -64, 128, 0)
	_height.allow_lesser = true
	_height.allow_greater = true
	_height.tooltip_text = "Placement plane (Page Up / Page Down); also used by Fill ground"
	_height.value_changed.connect(func(value): viewport.set_layer(int(value)))
	_brush_controls = _row(context)
	_turns = _spin(_brush_controls, "Quarter turns", 0, 3, 0)
	_mirror = CheckBox.new()
	_mirror.text = "Mirror brush"
	_brush_controls.add_child(_mirror)
	_brush_label = _line_label(context)
	_brush_label.custom_minimum_size.x = 120 * _scale
	_muted_labels.append(_brush_label)
	_shape_banner = _row(self)
	_shape_label = _line_label(_shape_banner)
	_button(_shape_banner, "Return to level", func(): _shape_mode.button_pressed = false, "Back")

func _build_palette(left: VBoxContainer) -> void:
	_heading(left, "Entity definitions")
	_palette = ItemList.new()
	_palette.custom_minimum_size = Vector2(0, 180) * _scale
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.fixed_icon_size = Vector2i(Vector2(16, 16) * _scale)
	_palette.item_selected.connect(_choose_definition)
	left.add_child(_palette)
	var assets = _row(left)
	_button(assets, "Entity", _new_definition, "Add", "Create a shared entity definition")
	_button(assets, "Import…", func(): _dialog("import_definition"), "Load")
	left.add_child(HSeparator.new())
	_definition_label = _heading(left, "Definition")
	_note(left, "Shared defaults affect all entities using this definition.")
	_definition_buttons.append(_button(left, "Edit in Inspector", func():
		if _definition: EditorInterface.edit_resource(_definition)
	, "Edit", "Edit this definition's shared defaults in Godot Inspector"))
	_shape_mode = CheckButton.new()
	_shape_mode.text = "Edit occupied cells"
	_shape_mode.toggled.connect(_toggle_shape)
	left.add_child(_shape_mode)
	var options = _fold(left, "Definition options")
	_definition_buttons.append(_button(options, "Save definition as…", func():
		if _definition: _dialog("save_definition")
	, "Save"))

func _build_selection(right: VBoxContainer) -> void:
	_entity_label = _label(right, "Use Select (3), then click an entity.")
	_entity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_single_entity = _column(right)
	_heading(_single_entity, "Transform")
	for axis in ["X", "Y", "Z"]:
		_coords.append(_spin(_single_entity, axis, -1024, 1024, 0))
		_coords.back().allow_greater = true
		_coords.back().allow_lesser = true
	_entity_turns = _spin(_single_entity, "Quarter turns", 0, 3, 0)
	_entity_mirror = CheckBox.new()
	_entity_mirror.text = "Mirrored"
	_single_entity.add_child(_entity_mirror)
	var overrides = _fold(_single_entity, "Property overrides")
	_note(overrides, "Only add values that differ from the definition.")
	_inspector = EditorInspector.new()
	_inspector.custom_minimum_size.y = 170 * _scale
	overrides.add_child(_inspector)
	_inspector.edit(_overrides)
	_reset_button = _button(overrides, "Reset all overrides", func():
		_overrides = GGPropertyOverrides.new()
		_inspector.edit(_overrides)
	, "Reload", "Clear the draft overrides; click Apply entity changes to commit")
	_apply_button = _button(_single_entity, "Apply entity changes", _apply_entity, "Apply")
	_note(_single_entity, "Property edits take effect when applied.")
	_selection_actions = _row(right)
	_duplicate_button = _button(_selection_actions, "Duplicate", _duplicate, "Duplicate", "Duplicate the selected entities")
	_delete_button = _button(_selection_actions, "Delete", _delete_selected, "Remove", "Delete selected entities (Delete); undo restores them")

func _build_level_settings(right: VBoxContainer) -> void:
	_heading(right, "Level settings")
	_label(right, "Title")
	_settings_title = LineEdit.new()
	right.add_child(_settings_title)
	_gravity = CheckBox.new()
	_gravity.text = "Enable gravity"
	right.add_child(_gravity)
	_void = _spin(right, "Fall-out height", -256, -1, -8)
	_button(right, "Apply level settings", func(): authoring.edit_settings(_settings_title.text, _gravity.button_pressed, int(_void.value)), "Apply")
	_note(right, "Title, gravity and fall-out height take effect when applied.")
	right.add_child(HSeparator.new())
	_label(right, "Game rule (optional)")
	_rule_picker = EditorResourcePicker.new()
	_rule_picker.base_type = "GGGameRule"
	_rule_picker.resource_changed.connect(func(resource):
		if not _updating: authoring.set_rule(resource)
	)
	_rule_picker.resource_selected.connect(func(resource, _inspect): EditorInterface.edit_resource(resource))
	right.add_child(_rule_picker)
	_note(right, "Rule changes apply immediately.")
	var floor = _fold(right, "Fill ground")
	_floor_hint = _note(floor, "Select a single-cell Ground definition in the palette.")
	_floor_height = _spin(floor, "Height", -64, 128, 0)
	_floor_height.allow_lesser = true
	_floor_height.allow_greater = true
	_floor_height.value_changed.connect(func(value): viewport.set_layer(int(value)))
	_floor_width = _spin(floor, "Width", 1, 64, 8)
	_floor_depth = _spin(floor, "Depth", 1, 64, 8)
	_floor_button = _button(floor, "Fill ground", _fill_floor, "Grid", "Fill using the selected Ground definition at the current height")
	_note(floor, "Starts at X=0, Z=0. Existing solid cells are skipped. Height is shared with the placement plane.")
	var transform = _fold(right, "Transform entire level")
	_note(transform, "Affects all entities. Each operation can be undone.")
	_button(transform, "Rotate level 90°", func(): authoring.transform_level(false), "RotateRight")
	_button(transform, "Mirror level on X", func(): authoring.transform_level(true), "MirrorX")

func _build_status() -> void:
	add_child(HSeparator.new())
	var row = _row(self)
	_status = _line_label(row)
	_pointer_status = _line_label(row)
	_pointer_status.size_flags_stretch_ratio = 0.6
	_pointer_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_muted_labels.append(_pointer_status)
	_button(row, "Details", func():
		_status_text.text = _status.tooltip_text
		_popup_text_dialog(_status_detail, Vector2(600, 420))
	, "Info", "Read the full last operation result")
	_status_detail = AcceptDialog.new()
	_status_text = _build_dialog_text(_status_detail, "Operation result")

func _build_help() -> void:
	_help = AcceptDialog.new()
	_help_text = _build_dialog_text(_help, "Grid Levels — keyboard shortcuts")
	_help_text.text = "TOOLS\n1 / 2 / 3: Paint / Erase / Select    •    Right click: pick brush\nShift+click: toggle selection    •    Delete: delete selected\nDrag axis / plane: move in whole cells    •    End: snap down\nQ / E: selected entities down / up    •    Esc: cancel move\nPage Up / Down: placement height\n\nCAMERA (viewport focus)\nWASD: fly    •    Q / E: fly down / up when no entity is selected\nRight+Q / E: fly with a selection    •    Right drag: look\nRight+wheel: speed    •    Middle: orbit    •    Shift+middle: pan\nWheel: zoom    •    F: frame    •    Esc: stop navigation\n\nAUTHORING\nCtrl/Cmd+S: save    •    Ctrl/Cmd+Z: undo\nCtrl/Cmd+Shift+Z or Ctrl/Cmd+Y: redo\n\nSHAPE EDITING\n1 / 2: add / remove occupied cells    •    Height: choose layer\nShape changes affect all entities sharing the definition.\n\nPLAYTEST\nWASD / arrows: move    •    Z / Y / R: undo / redo / restart"

func _build_dialog_text(dialog: AcceptDialog, title: String) -> RichTextLabel:
	dialog.title = title
	var text = RichTextLabel.new()
	# Keep the body's minimum size independent of the text length. RichTextLabel
	# wraps and scrolls internally, including at increased editor scale.
	text.fit_content = false
	text.selection_enabled = true
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(text)
	dialog.about_to_popup.connect(func(): text.scroll_to_line(0))
	add_child(dialog)
	return text

func _popup_text_dialog(dialog: AcceptDialog, preferred_size: Vector2) -> void:
	var bounds = Rect2i(get_viewport().get_visible_rect())
	if not dialog.is_embedded():
		bounds = Rect2i(get_window().position, get_window().size)
		var screen = DisplayServer.screen_get_usable_rect(get_window().current_screen)
		if screen.has_area(): bounds = bounds.intersection(screen)
	# Leave space for window decorations as well as the editor around the popup.
	var dialog_size = Vector2i((preferred_size * _scale).min(Vector2(bounds.size) * 0.85))
	dialog.min_size = dialog_size
	dialog.popup(Rect2i(bounds.position + (bounds.size - dialog_size) / 2, dialog_size))

func _button(parent: Node, text: String, action: Callable, icon_name: String = "", tip: String = "") -> Button:
	var button = Button.new()
	button.text = text
	button.tooltip_text = tip
	button.pressed.connect(action)
	parent.add_child(button)
	if not icon_name.is_empty(): _icon_buttons[button] = icon_name
	return button

func _label(parent: Node, text: String) -> Label:
	var label = Label.new()
	label.text = text
	if text.length() > 48:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	parent.add_child(label)
	return label

func _line_label(parent: Node) -> Label:
	var label = _label(parent, "")
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.clip_text = true
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	return label

func _heading(parent: Node, text: String) -> Label:
	var label = _label(parent, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_heading_labels.append(label)
	return label

func _note(parent: Node, text: String) -> Label:
	var label = _label(parent, text)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_muted_labels.append(label)
	return label

func _column(parent: Node) -> VBoxContainer:
	var column = VBoxContainer.new()
	column.add_theme_constant_override("separation", int(8 * _scale))
	parent.add_child(column)
	return column

func _row(parent: Node) -> HBoxContainer:
	var row = HBoxContainer.new()
	row.add_theme_constant_override("separation", int(6 * _scale))
	parent.add_child(row)
	return row

func _flow(parent: Node) -> HFlowContainer:
	var flow = HFlowContainer.new()
	flow.add_theme_constant_override("h_separation", int(18 * _scale))
	flow.add_theme_constant_override("v_separation", int(6 * _scale))
	parent.add_child(flow)
	return flow

func _scroll_column(parent: Node, minimum_width: float) -> VBoxContainer:
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = minimum_width * _scale
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	parent.add_child(scroll)
	var column = _column(scroll)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.size_flags_vertical = Control.SIZE_EXPAND_FILL
	return column

func _fold(parent: Node, title: String) -> VBoxContainer:
	var fold = FoldableContainer.new()
	fold.title = title
	fold.folded = true
	parent.add_child(fold)
	return _column(fold)

func _refresh_theme() -> void:
	var base = EditorInterface.get_base_control()
	for button in _icon_buttons:
		var icon_name: String = _icon_buttons[button]
		if base.has_theme_icon(icon_name, "EditorIcons"):
			button.icon = base.get_theme_icon(icon_name, "EditorIcons")
	for label in _muted_labels:
		label.add_theme_color_override("font_color", base.get_theme_color("font_color", "Editor").lerp(base.get_theme_color("disabled_font_color", "Editor"), 0.35))
	for label in _heading_labels:
		label.add_theme_font_override("font", base.get_theme_font("bold", "EditorFonts"))
	_title.add_theme_font_size_override("font_size", base.get_theme_font_size("font_size", "Label") + int(4 * _scale))
	_shape_label.add_theme_color_override("font_color", base.get_theme_color("warning_color", "Editor"))
	for button in _tool_buttons:
		button.add_theme_color_override("font_pressed_color", base.get_theme_color("accent_color", "Editor"))

func _sync_play_state() -> void:
	var playing = EditorInterface.is_playing_scene()
	_stop_button.disabled = not playing
	_play_button.disabled = playing

func _set_status(message: String) -> void:
	# Status changes must not resize the canvas during a drag. Preserve the
	# complete diagnostic in the tooltip while keeping the layout to one line.
	_status.text = message.replace("\n", " · ")
	_status.tooltip_text = message

func _spin(parent: Node, title: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	var row = _row(parent)
	var label = _label(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	spin.custom_minimum_size.x = 76 * _scale
	row.add_child(spin)
	return spin

func _guard(action: Callable) -> void:
	if authoring.dirty:
		_pending = action
		_confirm.popup_centered()
	else:
		action.call()

func request_open(level: GGLevel) -> void:
	if authoring.level == level:
		return
	_guard(func(): _open(level))

func _open(level: GGLevel) -> void:
	selection.select(&"")
	_definition = null
	if _shape_mode.button_pressed: _mode = _level_mode
	_shape_mode.set_pressed_no_signal(false)
	authoring.open(level)
	_choose_definition(0)
	viewport.frame_level()
	_set_status("Opened %s. Select an entity from the palette to start painting." % level.title)

func _new_level() -> void:
	var level = GGLevel.new()
	level.palette = GGDefaults.palette()
	_open(level)

func _refresh() -> void:
	_definition_refresh_pending = false
	if not is_instance_valid(viewport) or not authoring.level:
		return
	_updating = true
	var level = authoring.level
	_title.text = "%s%s" % [level.title, " *" if authoring.dirty else ""]
	_title.tooltip_text = "%s\n%s" % [level.title, level.resource_path if not level.resource_path.is_empty() else "Unsaved level"]
	_settings_title.text = level.title
	_gravity.set_pressed_no_signal(level.gravity_enabled)
	_void.set_value_no_signal(level.void_height)
	_rule_picker.edited_resource = level.game_rule
	_palette.clear()
	for definition in level.palette:
		var swatch = Image.create(16, 16, false, Image.FORMAT_RGBA8)
		swatch.fill(definition.color)
		_palette.add_item(definition.display_name, ImageTexture.create_from_image(swatch))
		_palette.set_item_tooltip(_palette.item_count - 1, "%s\n%s" % [definition.display_name, definition.definition_id])
		if definition == _definition:
			_palette.select(_palette.item_count - 1)
		if not definition.changed.is_connected(_definition_changed):
			definition.changed.connect(_definition_changed)
	_refresh_view()
	_update_selection()
	_updating = false

func _inspector_property_edited(_property: String) -> void:
	var resource = EditorInterface.get_inspector().get_edited_object()
	if resource is Resource and authoring.contains_configuration(resource):
		_definition_changed()

func _definition_changed() -> void:
	if _updating:
		return
	authoring.dirty = true
	if not _definition_refresh_pending:
		_definition_refresh_pending = true
		call_deferred("_refresh_definition_if_pending")

func _refresh_definition_if_pending() -> void:
	# Undo/redo already refreshes synchronously after emitting shape changes.
	# A stale deferred rebuild must not cancel a subsequently started drag.
	if _definition_refresh_pending:
		_refresh()

func _refresh_view() -> void:
	_configure_stroke()
	viewport.hide_ghost()
	if _shape_mode.button_pressed and _definition:
		var preview = GGLevel.new()
		var entity = GGEntityPlacement.new()
		entity.entity_id = &"shape_preview"
		entity.definition = _definition
		preview.entities.append(entity)
		viewport.show_level(preview)
	else:
		viewport.show_level(authoring.level)
	viewport.set_move_enabled(_mode == 2 and not _shape_mode.button_pressed)
	viewport.set_erase_enabled(_mode == 1 and not _shape_mode.button_pressed)
	_update_context()

func _toggle_shape(enabled: bool) -> void:
	# Shape entry can also switch tabs and hide the currently focused field.
	viewport.grab_focus()
	if enabled:
		_level_mode = _mode
		_select(&"")
		if _mode == 2: _mode = 0
	else:
		_mode = _level_mode
	_refresh_view()
	viewport.frame_level()

func _set_context_visible(control: Control, shown: bool) -> void:
	if not shown:
		var focus = get_viewport().gui_get_focus_owner()
		if focus and (focus == control or control.is_ancestor_of(focus)):
			# Hiding a focused descendant clears Godot's focus owner. Transfer it
			# first so the next shortcut remains scoped to this workspace.
			viewport.grab_focus()
	control.visible = shown

func _update_context() -> void:
	var shape = _shape_mode.button_pressed
	for index in range(_tool_buttons.size()):
		_tool_buttons[index].set_pressed_no_signal(_mode == index)
		_tool_buttons[index].disabled = shape and index == 2
	_tool_buttons[0].text = "Add cells (1)" if shape else "Paint (1)"
	_tool_buttons[1].text = "Remove (2)" if shape else "Erase (2)"
	_set_context_visible(_brush_controls, _mode == 0 and not shape)
	_brush_label.text = "Brush: " + _definition.display_name if _definition else "Choose an entity definition"
	_brush_label.tooltip_text = _brush_label.text
	_brush_label.visible = _mode == 0 and not shape
	_set_context_visible(_shape_banner, shape)
	_shape_label.text = "Shared shape: %s — affects all instances" % _definition.display_name if _definition else "Choose a definition"
	_shape_label.tooltip_text = _shape_label.text
	if selection.ids().is_empty():
		_entity_label.text = "Editing the shared definition. Use Add cells / Remove, then Return to level to select entities." if shape else "Use Select (3), then click an entity."
	_definition_label.text = _definition.display_name + " · Definition" if _definition else "Definition"
	_shape_mode.disabled = not _definition
	for button in _definition_buttons: button.disabled = not _definition
	if shape and _tabs.current_tab == 1: _tabs.current_tab = 0
	_tabs.set_tab_disabled(1, shape)
	var can_fill = _definition and _definition.shape.size() == 1 and _definition.defaults().get("ground", false)
	_floor_button.disabled = not can_fill or shape
	_floor_hint.text = "Using %s from the palette." % _definition.display_name if can_fill else "Select a single-cell Ground definition in the palette."
	if shape:
		_hint.text = "Click / drag: %s cells · Height: choose layer" % ("add" if _mode == 0 else "remove")
	else:
		_hint.text = ["Click / drag: paint · Right click: pick brush", "Click / drag: erase an entire entity", "Shift+click: multi-select · Drag: move · End: snap down"][_mode]
	_hint.tooltip_text = _hint.text + "\nSee Help for camera controls and all shortcuts."

func _choose_definition(index: int) -> void:
	if index >= 0 and index < authoring.level.palette.size():
		_definition = authoring.level.palette[index]
		_palette.select(index)
		_refresh_view()

func _pick_entity(id: StringName, button: int, shift: bool) -> void:
	if _shape_mode.button_pressed: return
	if button == MOUSE_BUTTON_RIGHT:
		var entity = authoring.find_entity(id)
		if entity:
			_choose_definition(authoring.level.palette.find(entity.definition))
			_turns.value = entity.quarter_turns
			_mirror.button_pressed = entity.mirrored
	elif _mode == 2:
		selection.select(id, shift)

func _configure_stroke() -> void:
	stroke.configure(_definition, _mode, int(_turns.value), _mirror.button_pressed, _shape_mode.button_pressed)

func _paint_height_changed(value: int) -> void:
	_height.set_value_no_signal(value)
	_floor_height.set_value_no_signal(value)
	var point = viewport.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, viewport.size).has_point(point):
		return
	var cell = viewport.input_cell_at(point)
	if cell != null:
		_hover(cell)

func _hover(cell: Vector3i) -> void:
	_last_hover = cell
	_pointer_status.text = "Cell %s · Height %d" % [cell, int(_height.value)]
	_pointer_status.tooltip_text = _pointer_status.text
	if not _definition or _mode != 0 or _shape_mode.button_pressed:
		viewport.hide_ghost()
		return
	viewport.show_ghost(_definition, cell, int(_turns.value), _mirror.button_pressed)

func _select(id: StringName, toggle: bool = false) -> void:
	selection.select(id, toggle)

func _update_selection() -> void:
	var single = selection.ids().size() == 1
	_set_context_visible(_single_entity, single)
	_set_context_visible(_selection_actions, not selection.ids().is_empty())
	_duplicate_button.disabled = selection.ids().is_empty()
	_delete_button.disabled = selection.ids().is_empty()
	for coord in _coords: coord.editable = single
	_entity_turns.editable = single
	_entity_mirror.disabled = not single
	_apply_button.disabled = not single
	_reset_button.disabled = not single
	_inspector.edit(null)
	if not single:
		_entity_label.text = "%d entities selected" % selection.ids().size() if not selection.ids().is_empty() else "Use Select, then click an entity."
		return
	var entity = authoring.find_entity(selection.active_id())
	_entity_label.text = "%s · %s" % [entity.definition.display_name, entity.entity_id]
	for axis in range(3): _coords[axis].value = entity.cell[axis]
	_entity_turns.value = entity.quarter_turns
	_entity_mirror.button_pressed = entity.mirrored
	_overrides = GGPropertyOverrides.new()
	_overrides.overrides = entity.overrides.duplicate(true)
	_inspector.edit(_overrides)

func _sync_coordinates() -> void:
	if selection.active_id() != &"":
		var cell = selection.position()
		for axis in range(3): _coords[axis].set_value_no_signal(cell[axis])

func _move_selection_height(offset: int) -> void:
	selection.translate(Vector3i(0, offset, 0))

func _snap_selected_to_ground() -> void:
	selection.snap_to_ground(viewport.rebase_move)

func _apply_entity() -> void:
	if selection.ids().size() != 1: return
	var cell = Vector3i(int(_coords[0].value), int(_coords[1].value), int(_coords[2].value))
	if not authoring.edit_entity(selection.active_id(), cell, int(_entity_turns.value), _entity_mirror.button_pressed, _overrides.overrides):
		_set_status(authoring.last_error if not authoring.last_error.is_empty() else "Select an entity first.")
	else:
		_set_status("Entity updated. Omitted overrides inherit their definition's defaults.")

func _duplicate() -> void:
	selection.duplicate()

func _delete_selected() -> void:
	selection.erase()

func _fill_floor() -> void:
	if not _definition or _definition.shape.size() != 1 or not _definition.defaults().get("ground", false):
		_set_status("Select a single-cell Ground entity in the palette first.")
		return
	authoring.fill_floor(_definition, Vector3i(0, int(_height.value), 0), int(_floor_width.value), int(_floor_depth.value))
	_set_status("Ground filled. Set height to 0 to place entities above a floor at -1.")

func _validate() -> bool:
	var errors = authoring.level.validate()
	_set_status("Level is valid." if errors.is_empty() else "\n".join(errors))
	return errors.is_empty()

func _dialog(action: String) -> void:
	_file_action = action
	_file.file_mode = EditorFileDialog.FILE_MODE_SAVE_FILE if action.begins_with("save") else EditorFileDialog.FILE_MODE_OPEN_FILE
	_file.title = action.capitalize().replace("_", " ")
	_file.current_file = "level.tres" if action == "save_level" else "entity.tres"
	_file.popup_centered_ratio(0.65)

func _file_selected(path: String) -> void:
	match _file_action:
		"open_level":
			var value = load(path)
			if value is GGLevel: _open(value)
			else: _set_status("This resource is not a Grid Game Groundwork level.")
		"import_definition":
			var value = load(path)
			if value is GGEntityDefinition:
				authoring.add_definition(value)
				_choose_definition(authoring.level.palette.find(value))
			else: _set_status("This resource is not an entity definition.")
		"save_level": _save_to(path)
		"save_definition":
			var error = ResourceSaver.save(_definition, path)
			if error == OK:
				_definition.take_over_path(path)
				authoring.dirty = true
				_set_status("Entity definition saved. Save the level to keep its reference.")
			else: _set_status("Could not save entity definition (error %d)." % error)

func save_current() -> void:
	if authoring.level.resource_path.is_empty():
		_dialog("save_level")
	else:
		_save_to(authoring.level.resource_path)

func _save_to(path: String) -> bool:
	var result = authoring.save(path)
	_set_status("Saved " + path if result == OK else authoring.last_error)
	if result == OK:
		EditorInterface.get_resource_filesystem().scan()
	return result == OK

func _playtest() -> void:
	if not _validate():
		return
	# Write a disposable copy, not the authored level. Playing never writes back.
	var dir = "res://.godot/grid_groundwork"
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(dir))
	var resource_path = dir + "/playtest.tres"
	var error = authoring.save_playtest(resource_path)
	if error != OK:
		_set_status("Could not prepare playtest (error %d)." % error)
		return
	var scene_path = dir + "/playtest.tscn"
	var scene = '[gd_scene load_steps=3 format=3]\n[ext_resource type="Script" path="res://addons/grid_game_groundwork/runtime/game.gd" id="1"]\n[ext_resource type="Resource" path="%s" id="2"]\n[node name="Playtest" type="Node3D"]\nscript = ExtResource("1")\nlevel = ExtResource("2")\n' % resource_path
	var file = FileAccess.open(scene_path, FileAccess.WRITE)
	if not file:
		_set_status("Could not write temporary playtest scene.")
		return
	file.store_string(scene)
	file.close()
	EditorInterface.play_custom_scene(scene_path)

func _new_definition() -> void:
	var dialog = ConfirmationDialog.new()
	dialog.title = "New entity definition"
	var name_input = LineEdit.new()
	name_input.placeholder_text = "Entity name"
	name_input.custom_minimum_size = Vector2(280, 36)
	dialog.add_child(name_input)
	add_child(dialog)
	dialog.confirmed.connect(func():
		var name = name_input.text.strip_edges()
		if name.is_empty(): name = "New entity"
		var definition = GGEntityDefinition.new()
		definition.display_name = name
		definition.definition_id = StringName(name.to_snake_case() + "_" + str(Time.get_ticks_usec()))
		authoring.add_definition(definition)
		_choose_definition(authoring.level.palette.size() - 1)
		EditorInterface.edit_resource(definition)
		dialog.queue_free()
	)
	dialog.canceled.connect(dialog.queue_free)
	dialog.popup_centered()
	name_input.grab_focus()

func _set_mode(index: int) -> void:
	if viewport.is_drawing() or (_shape_mode.button_pressed and index == 2):
		_update_context()
		return
	_mode = index
	_configure_stroke()
	viewport.set_move_enabled(index == 2 and not _shape_mode.button_pressed)
	viewport.set_erase_enabled(index == 1 and not _shape_mode.button_pressed)
	_update_context()
	_hover(_last_hover)

func _input(event: InputEvent) -> void:
	if viewport and viewport.is_navigating():
		return
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.ctrl_pressed or event.alt_pressed or event.shift_pressed or event.meta_pressed:
		return
	var key = event.keycode if event.keycode != KEY_NONE else event.physical_keycode
	var index = -1
	match key:
		KEY_1, KEY_KP_1: index = 0
		KEY_2, KEY_KP_2: index = 1
		KEY_3, KEY_KP_3: index = 2
		KEY_DELETE, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN: pass
		_: return
	var focus = get_viewport().gui_get_focus_owner()
	if not focus or not is_ancestor_of(focus):
		return
	if focus is LineEdit or focus is TextEdit or _inspector.is_ancestor_of(focus):
		return
	var modal = get_viewport().get_last_exclusive_window()
	if is_instance_valid(modal) and modal != get_window() and modal.visible:
		return
	if key == KEY_DELETE:
		if _mode == 2 and not _shape_mode.button_pressed and not selection.ids().is_empty():
			_delete_selected()
			get_viewport().set_input_as_handled()
		return
	if key in [KEY_PAGEUP, KEY_PAGEDOWN]:
		if not viewport.is_drawing():
			viewport.set_layer(viewport.layer + (1 if key == KEY_PAGEUP else -1))
			get_viewport().set_input_as_handled()
		return
	if key == KEY_END:
		if _mode == 2 and not _shape_mode.button_pressed and (not viewport.is_drawing() or viewport.is_moving()):
			_snap_selected_to_ground()
			get_viewport().set_input_as_handled()
		return
	if viewport.is_drawing() or (_shape_mode.button_pressed and index == 2):
		return
	_set_mode(index)
	get_viewport().set_input_as_handled()

func _unhandled_key_input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not event is InputEventKey or not event.pressed or event.echo:
		return
	if event.is_command_or_control_pressed():
		match event.keycode:
			KEY_S: save_current()
			KEY_Z:
				if event.shift_pressed: authoring.redo()
				else: authoring.undo()
			KEY_Y: authoring.redo()
			_: return
		get_viewport().set_input_as_handled()
