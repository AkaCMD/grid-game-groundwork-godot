@tool
class_name GGEditorPanel
extends VBoxContainer

var authoring = GGLevelAuthoring.new()
var viewport: GGEditorViewport
var _palette: ItemList
var _status: Label
var _title: Label
var _mode: OptionButton
var _height: SpinBox
var _turns: SpinBox
var _mirror: CheckBox
var _shape_mode: CheckButton
var _selected: StringName
var _selection: Array[StringName] = []
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
	add_theme_constant_override("separation", 8)
	var header = HBoxContainer.new()
	add_child(header)
	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 22)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_title)
	_button(header, "New level", func(): _guard(_new_level))
	_button(header, "Open…", func(): _guard(func(): _dialog("open_level")))
	_button(header, "Save", save_current)
	_button(header, "Save as…", func(): _dialog("save_level"))
	_button(header, "Playtest ▶", _playtest)
	_button(header, "Stop ■", func(): EditorInterface.stop_playing_scene())
	var toolbar = HBoxContainer.new()
	add_child(toolbar)
	_mode = OptionButton.new()
	for text in ["Paint (1)", "Erase (2)", "Select (3)"]: _mode.add_item(text)
	_mode.item_selected.connect(_set_mode)
	toolbar.add_child(_mode)
	_height = _spin(toolbar, "Height", -64, 128, 0)
	_height.allow_lesser = true
	_height.allow_greater = true
	_height.value_changed.connect(func(value): viewport.set_layer(int(value)))
	_turns = _spin(toolbar, "Quarter turns", 0, 3, 0)
	_mirror = CheckBox.new()
	_mirror.text = "Mirror brush"
	toolbar.add_child(_mirror)
	_button(toolbar, "Undo", authoring.undo)
	_button(toolbar, "Redo", authoring.redo)
	_button(toolbar, "Frame", func(): viewport.frame_level())
	_button(toolbar, "Validate", _validate)
	var split = HSplitContainer.new()
	split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	add_child(split)
	var left = VBoxContainer.new()
	left.custom_minimum_size.x = 190
	split.add_child(left)
	_label(left, "ENTITY PALETTE")
	_palette = ItemList.new()
	_palette.custom_minimum_size.y = 180
	_palette.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_palette.item_selected.connect(_choose_definition)
	left.add_child(_palette)
	var asset_row = HBoxContainer.new()
	left.add_child(asset_row)
	_button(asset_row, "+ Entity", _new_definition)
	_button(asset_row, "Import…", func(): _dialog("import_definition"))
	_button(left, "Edit definition in Inspector", func():
		if _definition: EditorInterface.edit_resource(_definition)
	)
	_button(left, "Save definition as…", func():
		if _definition: _dialog("save_definition")
	)
	_shape_mode = CheckButton.new()
	_shape_mode.text = "Edit occupied cells"
	_shape_mode.toggled.connect(func(value):
		if value: _select(&"")
		_refresh_view()
		viewport.frame_level()
	)
	left.add_child(_shape_mode)
	_label(left, "FLOOR FILL")
	_floor_width = _spin(left, "Width", 1, 64, 8)
	_floor_depth = _spin(left, "Depth", 1, 64, 8)
	_button(left, "Fill ground at current height", _fill_floor)
	_label(left, "Starts at X=0, Z=0.\nExisting solid cells are skipped.")
	_button(left, "Rotate entire level 90°", func(): authoring.transform_level(false))
	_button(left, "Mirror entire level on X", func(): authoring.transform_level(true))
	var center_right = HSplitContainer.new()
	center_right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	split.add_child(center_right)
	var center = VBoxContainer.new()
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center_right.add_child(center)
	viewport = GGEditorViewport.new()
	center.add_child(viewport)
	viewport.pressed.connect(func(cell, id, button, shift): _paint_or_pick(cell, id, button, false, shift))
	viewport.dragged.connect(func(cell, id): _paint_or_pick(cell, id, MOUSE_BUTTON_LEFT, true))
	viewport.stroke_started.connect(authoring.begin_stroke)
	viewport.stroke_ended.connect(authoring.end_stroke)
	viewport.hovered.connect(_hover)
	viewport.paint_cell_query = _brush_cell_at
	viewport.layer_changed.connect(_paint_height_changed)
	viewport.move_previewed.connect(_preview_entity_move)
	viewport.move_finished.connect(_finish_entity_move)
	_label(center, "1: Paint   •   2: Erase   •   3: Select   •   Shift+click: toggle selection   •   Delete: delete selected   •   Drag axis / plane: move (1-cell snap)   •   End: snap down   •   Esc: cancel   •   WASD: fly   •   Q/E: down/up   •   PgUp/PgDn: paint height   •   Right drag: look   •   Right+wheel: speed   •   Right click: eyedropper   •   Middle: orbit   •   Shift+middle: pan   •   Wheel: zoom   •   F: frame")
	var scroll = ScrollContainer.new()
	scroll.custom_minimum_size.x = 310
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	center_right.add_child(scroll)
	var right = VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(right)
	_label(right, "LEVEL")
	_settings_title = LineEdit.new()
	right.add_child(_settings_title)
	_gravity = CheckBox.new()
	_gravity.text = "Enable gravity"
	right.add_child(_gravity)
	_void = _spin(right, "Fall-out height", -256, -1, -8)
	_button(right, "Apply level settings", func(): authoring.edit_settings(_settings_title.text, _gravity.button_pressed, int(_void.value)))
	_label(right, "Game rule (optional)")
	_rule_picker = EditorResourcePicker.new()
	_rule_picker.base_type = "GGGameRule"
	_rule_picker.resource_changed.connect(func(resource):
		if not _updating: authoring.set_rule(resource)
	)
	_rule_picker.resource_selected.connect(func(resource, _inspect): EditorInterface.edit_resource(resource))
	right.add_child(_rule_picker)
	_label(right, "SELECTED ENTITY")
	_entity_label = _label(right, "Use Select, then click an entity.")
	for axis in ["X", "Y", "Z"]:
		_coords.append(_spin(right, axis, -1024, 1024, 0))
		_coords.back().allow_greater = true
		_coords.back().allow_lesser = true
	_entity_turns = _spin(right, "Quarter turns", 0, 3, 0)
	_entity_mirror = CheckBox.new()
	_entity_mirror.text = "Mirrored"
	right.add_child(_entity_mirror)
	_label(right, "Property overrides\nOnly add values that differ from the definition.")
	_inspector = EditorInspector.new()
	_inspector.custom_minimum_size.y = 200
	_inspector.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(_inspector)
	_inspector.edit(_overrides)
	_apply_button = _button(right, "Apply entity changes", _apply_entity)
	_reset_button = _button(right, "Reset all overrides", func():
		_overrides = GGPropertyOverrides.new()
		_inspector.edit(_overrides)
	)
	_button(right, "Duplicate selected", _duplicate)
	_button(right, "Delete selected", _delete_selected)
	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_OFF
	_status.clip_text = true
	_status.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	add_child(_status)
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
	authoring.changed.connect(_refresh)
	EditorInterface.get_inspector().property_edited.connect(_inspector_property_edited)
	_new_level()

func _button(parent: Node, text: String, action: Callable) -> Button:
	var button = Button.new()
	button.text = text
	button.pressed.connect(action)
	parent.add_child(button)
	return button

func _label(parent: Node, text: String) -> Label:
	var label = Label.new()
	label.text = text
	if text.length() > 48:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.custom_minimum_size.x = 160
	parent.add_child(label)
	return label

func _set_status(message: String) -> void:
	# Status changes must not resize the canvas during a drag. Preserve the
	# complete diagnostic in the tooltip while keeping the layout to one line.
	_status.text = message.replace("\n", " · ")
	_status.tooltip_text = message

func _spin(parent: Node, title: String, minimum: int, maximum: int, initial: int) -> SpinBox:
	var row = HBoxContainer.new()
	parent.add_child(row)
	var label = _label(row, title)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var spin = SpinBox.new()
	spin.min_value = minimum
	spin.max_value = maximum
	spin.value = initial
	spin.custom_minimum_size.x = 70
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
	viewport.cancel_move()
	_selection.clear()
	_selected = &""
	_definition = null
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
	_settings_title.text = level.title
	_gravity.set_pressed_no_signal(level.gravity_enabled)
	_void.set_value_no_signal(level.void_height)
	_rule_picker.edited_resource = level.game_rule
	_palette.clear()
	for definition in level.palette:
		_palette.add_item(definition.display_name)
		_palette.set_item_custom_fg_color(_palette.item_count - 1, definition.color.lightened(0.2))
		if definition == _definition:
			_palette.select(_palette.item_count - 1)
		if not definition.changed.is_connected(_definition_changed):
			definition.changed.connect(_definition_changed)
	_selection = _selection.filter(func(id): return authoring.find_entity(id) != null)
	_selected = _selection.back() if not _selection.is_empty() else &""
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
	if _shape_mode.button_pressed: viewport.select_entity(&"")
	else: viewport.select_entities(_selection)
	viewport.set_move_enabled(_mode.selected == 2 and not _shape_mode.button_pressed)
	viewport.set_erase_enabled(_mode.selected == 1 and not _shape_mode.button_pressed)

func _choose_definition(index: int) -> void:
	if index >= 0 and index < authoring.level.palette.size():
		_definition = authoring.level.palette[index]
		_palette.select(index)
		_refresh_view()

func _paint_or_pick(cell: Vector3i, id: StringName, button: int, drag: bool = false, shift: bool = false) -> void:
	if _shape_mode.button_pressed:
		if _definition:
			var remove = _mode.selected == 1
			if button != MOUSE_BUTTON_LEFT: return
			authoring.edit_shape(_definition, cell, remove)
		return
	if button == MOUSE_BUTTON_RIGHT:
		var entity = authoring.find_entity(id)
		if entity:
			_choose_definition(authoring.level.palette.find(entity.definition))
			_turns.value = entity.quarter_turns
			_mirror.button_pressed = entity.mirrored
		return
	match _mode.selected:
		0:
			if _definition:
				authoring.paint(_definition, cell, int(_turns.value), _mirror.button_pressed)
		1:
			if id != &"": authoring.erase(id)
		2:
			if not drag: _select(id, shift)

func _brush_cell_at(point: Vector2) -> Variant:
	if _shape_mode.button_pressed or not _definition:
		return viewport.cell_at(point)
	var hit = viewport.surface_at(point)
	if hit.is_empty():
		return viewport.cell_at(point)
	var normal: Vector3i = hit.normal
	var axis = Vector3(normal).abs().max_axis_index()
	var offsets: Array[Vector3i] = []
	for cell in _definition.shape:
		offsets.append(GGGrid.transform_cell(cell, int(_turns.value), _mirror.button_pressed))
	if offsets.is_empty(): return null
	# Put the brush's contacting face against the picked face, including shapes
	# whose occupied cells extend below or to either side of their origin.
	var edge = offsets[0][axis]
	for offset in offsets:
		edge = mini(edge, offset[axis]) if normal[axis] > 0 else maxi(edge, offset[axis])
	var target: Vector3i = hit.cell + normal
	target[axis] -= edge
	return target

func _paint_height_changed(value: int) -> void:
	_height.set_value_no_signal(value)
	var point = viewport.get_local_mouse_position()
	if not Rect2(Vector2.ZERO, viewport.size).has_point(point):
		return
	var cell = viewport.input_cell_at(point)
	if cell != null:
		_hover(cell)

func _hover(cell: Vector3i) -> void:
	_last_hover = cell
	if not _definition or _mode.selected != 0 or _shape_mode.button_pressed:
		viewport.hide_ghost()
		return
	var target = authoring.placement_cell(_definition, cell, int(_turns.value), _mirror.button_pressed)
	if target != null:
		viewport.show_ghost(_definition, target, int(_turns.value), _mirror.button_pressed)
		_set_status("Brush: %s   •   Place at %s   •   %d entities" % [_definition.display_name, target, authoring.level.entities.size()])

func _select(id: StringName, toggle: bool = false) -> void:
	viewport.cancel_move()
	if toggle:
		if id != &"":
			if _selection.has(id): _selection.erase(id)
			elif authoring.find_entity(id): _selection.append(id)
	else:
		_selection.clear()
		if authoring.find_entity(id): _selection.append(id)
	_selected = _selection.back() if not _selection.is_empty() else &""
	viewport.select_entities(_selection)
	_update_selection()

func _update_selection() -> void:
	var single = _selection.size() == 1
	for coord in _coords: coord.editable = single
	_entity_turns.editable = single
	_entity_mirror.disabled = not single
	_apply_button.disabled = not single
	_reset_button.disabled = not single
	_inspector.edit(null)
	if not single:
		_entity_label.text = "%d entities selected" % _selection.size() if not _selection.is_empty() else "Use Select, then click an entity."
		return
	var entity = authoring.find_entity(_selected)
	_entity_label.text = "%s · %s" % [entity.definition.display_name, entity.entity_id]
	for axis in range(3): _coords[axis].value = entity.cell[axis]
	_entity_turns.value = entity.quarter_turns
	_entity_mirror.button_pressed = entity.mirrored
	_overrides = GGPropertyOverrides.new()
	_overrides.overrides = entity.overrides.duplicate(true)
	_inspector.edit(_overrides)

func _sync_coordinates() -> void:
	var entity = authoring.find_entity(_selected)
	if entity:
		for axis in range(3): _coords[axis].set_value_no_signal(entity.cell[axis])
	else:
		_entity_label.text = "Use Select, then click an entity."

func _preview_entity_move(id: StringName, cell: Vector3i) -> void:
	var entity = authoring.find_entity(id)
	if not entity: return
	var error = authoring.translation_error(_selection, cell - entity.cell)
	viewport.preview_move(cell, error.is_empty())
	for axis in range(3): _coords[axis].set_value_no_signal(cell[axis])
	_set_status("Move to %s · 1-cell snap · Esc to cancel" % cell if error.is_empty() else "Invalid destination: %s\nRelease to restore the original position." % error)

func _finish_entity_move(id: StringName, cell: Vector3i, commit: bool) -> void:
	var entity = authoring.find_entity(id)
	if commit and entity:
		# Preview never changes the authored resource. Commit exactly once,
		# preserving every selected entity's saved orientation and overrides.
		if authoring.translate_entities(_selection, cell - entity.cell):
			_set_status("Moved to %s." % cell)
		else:
			_set_status(authoring.last_error)
	else:
		_set_status("Move cancelled; original position restored.")
	_sync_coordinates()

func _snap_selected_to_ground() -> void:
	if _selection.size() > 1:
		_set_status("Snap down is available only for a single selected entity.")
		return
	var entity = authoring.find_entity(_selected)
	if not entity:
		_set_status("Select an entity first.")
		return
	var moving = viewport.is_moving()
	var origin = viewport.move_position() if moving else entity.cell
	var target = authoring.ground_position(_selected, origin)
	if target == null:
		_set_status(authoring.last_error)
		return
	if target == origin:
		_set_status("Entity is already supported.")
		return
	if moving:
		if viewport.rebase_move(target):
			_set_status("Snapped to %s · Continue dragging · Esc to cancel" % target)
		else:
			_set_status("Cannot snap from this camera angle. Cancel the drag and orbit the camera.")
	elif authoring.edit_entity(_selected, target, entity.quarter_turns, entity.mirrored, entity.overrides):
		_set_status("Snapped to %s." % target)
	else:
		_set_status(authoring.last_error)

func _apply_entity() -> void:
	if _selection.size() != 1: return
	var cell = Vector3i(int(_coords[0].value), int(_coords[1].value), int(_coords[2].value))
	if not authoring.edit_entity(_selected, cell, int(_entity_turns.value), _entity_mirror.button_pressed, _overrides.overrides):
		_set_status(authoring.last_error if not authoring.last_error.is_empty() else "Select an entity first.")
	else:
		_set_status("Entity updated. Omitted overrides inherit their definition's defaults.")

func _duplicate() -> void:
	viewport.cancel_move()
	var copies = authoring.duplicate_entities(_selection)
	if copies.is_empty():
		_set_status(authoring.last_error)
		return
	_selection.assign(copies)
	_selected = _selection.back()
	viewport.select_entities(_selection)
	_update_selection()
	_set_status("Duplicated %d entities." % copies.size())

func _delete_selected() -> void:
	viewport.cancel_move()
	if authoring.erase_entities(_selection): _select(&"")
	else: _set_status(authoring.last_error)

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
	_mode.select(index)
	viewport.set_move_enabled(index == 2 and not _shape_mode.button_pressed)
	viewport.set_erase_enabled(index == 1 and not _shape_mode.button_pressed)
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
		if _mode.selected == 2 and not _shape_mode.button_pressed and not _selection.is_empty():
			_delete_selected()
			get_viewport().set_input_as_handled()
		return
	if key in [KEY_PAGEUP, KEY_PAGEDOWN]:
		if not viewport.is_drawing():
			viewport.set_layer(viewport.layer + (1 if key == KEY_PAGEUP else -1))
			get_viewport().set_input_as_handled()
		return
	if key == KEY_END:
		if _mode.selected == 2 and not _shape_mode.button_pressed and (not viewport.is_drawing() or viewport.is_moving()):
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
