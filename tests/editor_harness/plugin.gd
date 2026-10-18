@tool
extends EditorPlugin
var failures = 0

func _enter_tree() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func find_panel(node: Node) -> GGEditorPanel:
	if node is GGEditorPanel:
		return node
	for child in node.get_children():
		var result = find_panel(child)
		if result: return result
	return null

func run() -> void:
	for frame in range(30): await get_tree().process_frame
	var panel = find_panel(EditorInterface.get_editor_main_screen())
	check(panel != null, "Grid Levels panel exists in the actual editor")
	if not panel:
		get_tree().quit(1)
		return
	await check_workspace_shortcuts(panel)
	var example: GGLevel = load("res://examples/levels/sokoban.tres")
	var example_count = example.entities.size()
	panel.request_open(example)
	for frame in range(10): await get_tree().process_frame
	check(panel.viewport.level.title == "Garden of crates", "Example opens in the visual workspace")
	check(panel.viewport.board.roots.size() == example_count, "All example entities have visual instances")
	panel._new_level()
	panel._choose_definition(0)
	panel._height.value = -1
	panel._floor_width.value = 4
	panel._floor_depth.value = 3
	panel._fill_floor()
	check(panel.authoring.level.entities.size() == 12, "Floor-fill button creates ground")
	panel._choose_definition(3)
	panel._height.value = 0
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = panel.viewport.camera.unproject_position(Vector3.ZERO)
	panel.viewport.gui_input.emit(click)
	click.pressed = false
	panel.viewport.gui_input.emit(click)
	click.pressed = true
	panel.viewport.gui_input.emit(click)
	click.pressed = false
	panel.viewport.gui_input.emit(click)
	check(panel.authoring.level.entities.back().cell == Vector3i.UP, "Painting in the workspace stacks entities")
	await check_mode_shortcuts(panel)
	await check_move_gizmo(panel)
	await check_end_snap(panel)
	panel._shape_mode.button_pressed = true
	panel._paint_or_pick(Vector3i.RIGHT, &"", MOUSE_BUTTON_LEFT)
	check(panel._definition.shape.size() == 2, "Visual shape editor updates the selected definition")
	panel.authoring.undo()
	check(panel._definition.shape.size() == 1, "Shape editing can be undone through the editor")
	panel._shape_mode.button_pressed = false
	check(panel._save_to("res://editor_smoke_level.tres"), "Editor saves level")
	panel._new_level()
	panel.request_open(load("res://editor_smoke_level.tres"))
	check(panel.authoring.level.entities.size() == 14, "Saved level reopens in editor")
	panel.request_open(load("res://examples/levels/sokoban.tres"))
	panel.viewport.frame_level()
	panel._playtest()
	for frame in range(60): await get_tree().process_frame
	check(EditorInterface.is_playing_scene(), "One-click playtest starts a game process")
	EditorInterface.stop_playing_scene()
	check(panel.authoring.level.entities.size() == example_count, "Playtest leaves the authored level unchanged")
	for frame in range(30): await get_tree().process_frame
	if DisplayServer.get_name() != "headless" and not OS.get_environment("GGG_EDITOR_SCREENSHOT").is_empty():
		panel._set_mode(2)
		for entity in panel.authoring.level.entities:
			if entity.definition.shape.size() > 1:
				panel._select(entity.entity_id)
				break
		panel.viewport._yaw = 0.5
		panel.viewport._pitch = 0.8
		panel.viewport._camera_position()
		for frame in range(5): await get_tree().process_frame
		var image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		image.save_png(OS.get_environment("GGG_EDITOR_SCREENSHOT"))
	await check_quack(panel)
	print("EDITOR_SMOKE: %d failures" % failures)
	get_tree().quit(1 if failures else 0)

func mode_key(code: Key, modifiers: int = 0, echo: bool = false, pressed: bool = true) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	event.ctrl_pressed = bool(modifiers & KEY_MASK_CTRL)
	event.alt_pressed = bool(modifiers & KEY_MASK_ALT)
	event.shift_pressed = bool(modifiers & KEY_MASK_SHIFT)
	event.meta_pressed = bool(modifiers & KEY_MASK_META)
	Input.parse_input_event(event)
	await get_tree().process_frame

func check_workspace_shortcuts(panel: GGEditorPanel) -> void:
	for screen in ["3D", "2D"]:
		EditorInterface.set_main_screen_editor(screen)
		EditorInterface.get_inspector().grab_focus()
		await get_tree().process_frame
		EditorInterface.set_main_screen_editor("Grid Levels")
		await get_tree().process_frame
		for binding in [[KEY_2, 1], [KEY_3, 2], [KEY_1, 0]]:
			await mode_key(binding[0])
			check(panel._mode.selected == binding[1], "Entering Grid Levels enables number shortcuts without a canvas click")

func check_mode_shortcuts(panel: GGEditorPanel) -> void:
	panel.viewport.grab_focus()
	for binding in [[KEY_2, 1], [KEY_3, 2], [KEY_1, 0], [KEY_KP_2, 1], [KEY_KP_3, 2], [KEY_KP_1, 0]]:
		await mode_key(binding[0])
		check(panel._mode.selected == binding[1], "Number row and keypad switch authoring modes")
	panel._hover(Vector3i.ZERO)
	await mode_key(KEY_2)
	check(not panel.viewport._ghost.visible, "Erase immediately hides the brush preview")
	await mode_key(KEY_1)
	check(panel.viewport._ghost.visible, "Paint immediately restores the brush preview")
	for modifiers in [KEY_MASK_CTRL, KEY_MASK_ALT, KEY_MASK_SHIFT, KEY_MASK_META]:
		await mode_key(KEY_2, modifiers)
		check(panel._mode.selected == 0, "Modified number keys do not switch modes")
	await mode_key(KEY_2, 0, true)
	await mode_key(KEY_2, 0, false, false)
	check(panel._mode.selected == 0, "Key repeat and release do not switch modes")
	panel._settings_title.grab_focus()
	await mode_key(KEY_2)
	check(panel._mode.selected == 0, "Title entry does not switch modes")
	panel._height.get_line_edit().grab_focus()
	await mode_key(KEY_KP_2)
	check(panel._mode.selected == 0, "Coordinate entry does not switch modes")
	panel._mirror.grab_focus()
	await mode_key(KEY_2)
	check(panel._mode.selected == 1, "Shortcuts work outside the canvas within the panel")
	panel._confirm.popup_centered()
	await get_tree().process_frame
	await mode_key(KEY_3)
	check(panel._mode.selected == 1, "Modal dialogs block mode shortcuts")
	panel._confirm.hide()
	panel.viewport.grab_focus()
	panel.viewport._drawing = true
	await mode_key(KEY_3)
	check(panel._mode.selected == 1, "An active stroke blocks mode shortcuts")
	panel.viewport._drawing = false
	await mode_key(KEY_3)
	check(panel._mode.selected == 2, "Switching resumes after the stroke")
	panel._shape_mode.button_pressed = true
	await mode_key(KEY_1)
	await mode_key(KEY_3)
	check(panel._mode.selected == 0, "Shape editing ignores Select")
	await mode_key(KEY_2)
	check(panel._mode.selected == 1, "Shape editing supports Erase")
	await mode_key(KEY_1)
	check(panel._mode.selected == 0, "Shape editing supports Paint")
	panel._shape_mode.button_pressed = false
	panel.hide()
	await mode_key(KEY_2)
	check(panel._mode.selected == 0, "Hidden panel ignores mode shortcuts")
	panel.show()
	EditorInterface.get_inspector().grab_focus()
	await mode_key(KEY_2)
	check(panel._mode.selected == 0, "Focus outside the panel ignores mode shortcuts")
	panel.viewport.grab_focus()

func gizmo_press(panel: GGEditorPanel, handle: int) -> Vector3:
	var view = panel.viewport
	var gizmo = view._move_gizmo
	gizmo.update_view()
	var local: Vector3 = gizmo.AXES[handle] * 0.85 if handle < 3 else gizmo.MASKS[handle] * 0.375
	var grabbed = gizmo.to_global(local)
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.position = view.camera.unproject_position(grabbed)
	view.gui_input.emit(event)
	check(view.is_moving() and gizmo.active_handle == handle, "Picking handle %d starts a constrained drag" % handle)
	return grabbed

func gizmo_motion(panel: GGEditorPanel, world_point: Vector3) -> void:
	var event = InputEventMouseMotion.new()
	event.button_mask = MOUSE_BUTTON_MASK_LEFT
	event.position = panel.viewport.camera.unproject_position(world_point)
	panel.viewport.gui_input.emit(event)

func gizmo_release(panel: GGEditorPanel, world_point: Vector3) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = false
	event.position = panel.viewport.camera.unproject_position(world_point)
	panel.viewport.gui_input.emit(event)

func check_move_gizmo(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	fixture.palette[3].shape.assign([Vector3i.ZERO, Vector3i.RIGHT])
	var entity = GGEntityPlacement.new()
	entity.entity_id = &"moving"
	entity.definition = fixture.palette[3]
	entity.cell = Vector3i(2, 2, 2)
	entity.quarter_turns = 1
	entity.mirrored = true
	entity.overrides = {"weight": 9.0}
	fixture.entities.append(entity)
	panel._open(fixture)
	panel._set_mode(2)
	panel._select(entity.entity_id)
	var view = panel.viewport
	view._pivot = Vector3(entity.cell)
	view._yaw = 0.65
	view._pitch = 0.65
	view._zoom = 10.0
	view._camera_position()
	await get_tree().process_frame
	var original = entity.cell
	var offsets = [Vector3(2, 0, 0), Vector3(0, 2, 0), Vector3(0, 0, -2), Vector3(2, -1, 0), Vector3(-2, 0, 1), Vector3(0, 2, -1)]
	for camera_yaw in [-0.65, 0.65]:
		view._yaw = camera_yaw
		view._camera_position()
		for handle in range(6):
			var grabbed = gizmo_press(panel, handle)
			gizmo_motion(panel, grabbed + offsets[handle] * 0.1)
			check(view._move_target == original, "Sub-half-cell pointer motion stays snapped to the original cell")
			gizmo_motion(panel, grabbed + offsets[handle])
			var target = original + Vector3i(offsets[handle])
			check(view._move_target == target, "Handle %d snaps only its active axes" % handle)
			check(panel.authoring.find_entity(entity.entity_id).cell == original, "Dragging leaves authored data untouched until release")
			check(view.board.roots[entity.entity_id].position == Vector3(target), "Visual preview follows the snapped destination")
			for axis in range(3): check(int(panel._coords[axis].value) == target[axis], "Coordinate fields follow preview")
			gizmo_release(panel, grabbed + offsets[handle])
			var moved = panel.authoring.find_entity(entity.entity_id)
			check(moved.cell == target and moved.quarter_turns == 1 and moved.mirrored and moved.overrides.weight == 9.0, "Release commits position and preserves entity properties")
			check(panel.authoring.undo() and panel.authoring.find_entity(entity.entity_id).cell == original, "A complete drag is one undo action")
			for axis in range(3): check(int(panel._coords[axis].value) == original[axis], "Undo refreshes coordinate fields")
			check(panel.authoring.redo() and panel.authoring.find_entity(entity.entity_id).cell == target, "Move can be redone")
			panel.authoring.undo()
	var history_size = panel.authoring._history.size()
	var grabbed = gizmo_press(panel, 0)
	gizmo_release(panel, grabbed)
	check(panel.authoring._history.size() == history_size, "Clicking a handle without moving does not add undo actions")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3(3, 0, 0))
	await mode_key(KEY_ESCAPE)
	check(not view.is_moving() and view.board.roots[entity.entity_id].position == Vector3(original), "Esc restores the original visual position")
	check(panel.authoring._history.size() == history_size, "Cancelled moves do not add undo actions")
	var blocker = GGEntityPlacement.new()
	blocker.entity_id = &"blocker"
	blocker.definition = fixture.palette[3]
	blocker.cell = original + Vector3i(3, 0, 0)
	fixture.entities.append(blocker)
	panel._refresh()
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	for frame in range(4): await get_tree().process_frame
	var valid_rect = view.get_global_rect()
	var valid_status_height = panel._status.size.y
	gizmo_motion(panel, grabbed + Vector3(3, 0, 0))
	for frame in range(4): await get_tree().process_frame
	check(view.get_global_rect() == valid_rect and panel._status.size.y == valid_status_height, "Invalid destination status must not resize or move the editing viewport")
	check(panel._status.tooltip_text.contains("Invalid destination:") and panel._status.tooltip_text.contains("Release to restore"), "Full invalid destination details remain available in the tooltip")
	check(not view._move_valid and view._selected.get_child(0).material_override.albedo_color.r > 0.9, "Solid overlap displays a red invalid preview")
	gizmo_release(panel, grabbed + Vector3(3, 0, 0))
	check(panel.authoring.find_entity(entity.entity_id).cell == original and view.board.roots[entity.entity_id].position == Vector3(original), "Invalid release restores the starting position")
	check(panel.authoring._history.size() == history_size, "Invalid release does not add undo actions")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3(6, 0, 0))
	check(view._move_valid, "Dragging across an obstacle to free cells is permitted")
	gizmo_release(panel, grabbed + Vector3(6, 0, 0))
	check(panel.authoring.save("res://gizmo_smoke_level.tres") == OK, "Gizmo move saves")
	var reloaded = ResourceLoader.load("res://gizmo_smoke_level.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(reloaded.entities[0].cell == original + Vector3i(6, 0, 0), "Gizmo move survives save/reload")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	view.get_window().focus_exited.emit()
	check(not view.is_moving() and view.board.roots[entity.entity_id].position == Vector3(original + Vector3i(6, 0, 0)), "Losing window focus cancels an unfinished move")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	panel.hide()
	check(not view.is_moving(), "Hiding the panel cancels an unfinished drag")
	panel.show()
	panel._set_mode(0)
	check(not view._move_gizmo.visible, "Paint mode hides movement handles")
	panel._set_mode(2)
	panel._shape_mode.button_pressed = true
	check(not view._move_gizmo.visible, "Shape editing hides movement handles")
	panel._shape_mode.button_pressed = false
	# Restore the original smoke-test fixture for its remaining checks.
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	panel._set_mode(0)

func check_end_snap(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.gravity_enabled = false
	fixture.palette = GGDefaults.palette()
	fixture.palette[0].shape.clear()
	for x in range(-6, 7):
		for z in range(-6, 7):
			fixture.palette[0].shape.append(Vector3i(x, 0, z))
	var floor_entity = GGEntityPlacement.new()
	floor_entity.entity_id = &"floor"
	floor_entity.definition = fixture.palette[0]
	floor_entity.cell = Vector3i.DOWN
	fixture.entities.append(floor_entity)
	var entity = GGEntityPlacement.new()
	entity.entity_id = &"snap_selection"
	entity.definition = fixture.palette[3]
	entity.definition.shape.assign([Vector3i.ZERO, Vector3i.RIGHT])
	entity.cell = Vector3i(0, 6, 0)
	entity.quarter_turns = 1
	entity.mirrored = true
	entity.overrides = {"weight": 8.0}
	fixture.entities.append(entity)
	panel._open(fixture)
	panel._set_mode(2)
	panel._select(entity.entity_id)
	var view = panel.viewport
	view._pivot = Vector3(0, 3, 0)
	view._yaw = 0.65
	view._pitch = 0.65
	view._zoom = 12.0
	view._camera_position()
	view.grab_focus()
	await get_tree().process_frame
	var original = entity.cell
	await mode_key(KEY_END)
	check(panel.authoring.find_entity(entity.entity_id).cell == Vector3i.ZERO, "End snaps the idle selection down to explicit ground even with gravity disabled")
	check(panel.authoring.undo() and panel.authoring.find_entity(entity.entity_id).cell == original, "Idle End is one undo action")
	check(panel.authoring.redo() and panel.authoring.find_entity(entity.entity_id).cell == Vector3i.ZERO, "Idle End can be redone")
	var history_size = panel.authoring._history.size()
	await mode_key(KEY_END)
	check(panel.authoring._history.size() == history_size, "End on an already supported entity does not create history")
	panel.authoring.undo()
	var offsets = [Vector3(2, 0, 0), Vector3(0, 2, 0), Vector3(0, 0, 2), Vector3(2, 1, 0), Vector3(2, 0, 1), Vector3(0, 1, 1)]
	for handle in range(6):
		var grabbed = gizmo_press(panel, handle)
		gizmo_motion(panel, grabbed + offsets[handle])
		var before_snap = view._move_target
		history_size = panel.authoring._history.size()
		await mode_key(KEY_END)
		var snapped = Vector3i(before_snap.x, 0, before_snap.z)
		check(view.is_moving() and view._move_gizmo.active_handle == handle and view._move_target == snapped, "End snaps preview while retaining handle %d" % handle)
		check(panel.authoring.find_entity(entity.entity_id).cell == original and panel.authoring._history.size() == history_size, "Mid-drag End does not commit or add history")
		check(view._move_gizmo.target_at(view._move_pointer) == snapped, "Pointer anchor rebases after End without jumping back")
		for axis in range(3): check(int(panel._coords[axis].value) == snapped[axis], "Coordinates follow the grounded preview")
		var anchor = view._move_gizmo._start_hit
		var delta: Vector3 = view._move_gizmo.MASKS[handle]
		gizmo_motion(panel, anchor + delta)
		var final_cell = snapped + Vector3i(delta)
		check(view._move_target == final_cell, "Continued dragging retains its axis/plane constraint after End")
		gizmo_release(panel, anchor + delta)
		var moved = panel.authoring.find_entity(entity.entity_id)
		check(moved.cell == final_cell and moved.quarter_turns == 1 and moved.mirrored and moved.overrides.weight == 8.0, "Ground snap and continuation preserve the complete entity")
		check(panel.authoring._history.size() == history_size + 1, "Drag plus End plus continued movement creates exactly one undo action")
		check(panel.authoring.undo() and panel.authoring.find_entity(entity.entity_id).cell == original, "One undo restores the position before the entire drag")
		check(panel.authoring.redo() and panel.authoring.find_entity(entity.entity_id).cell == final_cell, "One redo restores the entire drag and snap")
		panel.authoring.undo()
	var grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	history_size = panel.authoring._history.size()
	await mode_key(KEY_END)
	await mode_key(KEY_ESCAPE)
	check(not view.is_moving() and view.board.roots[entity.entity_id].position == Vector3(original) and panel.authoring.find_entity(entity.entity_id).cell == original, "Esc after End restores the position before dragging")
	check(panel.authoring._history.size() == history_size, "Cancelling a snapped drag adds no history")
	# A wall top is a valid support, without any Ground property.
	var wall = GGEntityPlacement.new()
	wall.entity_id = &"support_wall"
	wall.definition = fixture.palette[1]
	wall.cell = Vector3i(0, 2, 0)
	fixture.entities.append(wall)
	panel._refresh()
	await mode_key(KEY_END)
	check(panel.authoring.find_entity(entity.entity_id).cell == Vector3i(0, 3, 0), "End stops at the nearest solid entity above ground")
	panel.authoring.undo()
	# An overlapping preview remains red and is not teleported through solids.
	grabbed = gizmo_press(panel, 1)
	gizmo_motion(panel, grabbed + Vector3(0, -4, 0))
	var invalid = view._move_target
	await mode_key(KEY_END)
	check(not view._move_valid and view._move_target == invalid and panel._status.text.contains("overlapping"), "End rejects an overlapping preview without changing it")
	await mode_key(KEY_ESCAPE)
	# Outside the authored floor, there is no invisible Y=0 fallback.
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3(20, 0, 0))
	var unsupported = view._move_target
	history_size = panel.authoring._history.size()
	await mode_key(KEY_END)
	check(view._move_target == unsupported and panel._status.text.contains("No supporting surface"), "End over a gap keeps the preview in place and explains why")
	check(panel.authoring._history.size() == history_size, "Failed End adds no history")
	await mode_key(KEY_ESCAPE)
	# End must continue to work as a text-navigation key in input fields.
	for focus in [panel._settings_title, panel._coords[0].get_line_edit()]:
		focus.grab_focus()
		await mode_key(KEY_END)
		check(panel.authoring.find_entity(entity.entity_id).cell == original, "End does not snap while editing a text or coordinate field")
	view.grab_focus()
	for modifiers in [KEY_MASK_CTRL, KEY_MASK_SHIFT, KEY_MASK_ALT, KEY_MASK_META]:
		await mode_key(KEY_END, modifiers)
		check(panel.authoring.find_entity(entity.entity_id).cell == original, "Modified End does not snap")
	panel._confirm.popup_centered()
	await get_tree().process_frame
	await mode_key(KEY_END)
	check(panel.authoring.find_entity(entity.entity_id).cell == original, "Modal dialog blocks End")
	panel._confirm.hide()
	view.grab_focus()
	panel._set_mode(0)
	await mode_key(KEY_END)
	check(panel.authoring.find_entity(entity.entity_id).cell == original, "End is scoped to Select")
	panel._set_mode(2)
	await mode_key(KEY_END)
	check(panel.authoring.save("res://snap_smoke_level.tres") == OK, "Snapped entity saves")
	var reloaded = ResourceLoader.load("res://snap_smoke_level.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(reloaded.entities[1].cell == Vector3i(0, 3, 0), "End position survives save/reload")
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	panel._set_mode(0)

func check_quack(panel: GGEditorPanel) -> void:
	panel.request_open(load("res://examples/levels/quack.tres"))
	await get_tree().process_frame
	check(panel.authoring.level.title.begins_with("QUACK"), "QUACK opens in Grid Levels")
	panel._set_mode(2)
	panel._select(&"duck_b")
	var board = panel.viewport.board
	var duck = board.roots[&"duck_b"].get_child(0)
	check(duck.get_child(0).material_override.get_shader_parameter("background_color") == Color.BLACK, "Editor selection uses the shared black duck background")
	panel._select(&"duck_c")
	check(duck.get_child(0).material_override.get_shader_parameter("background_color") == Color.WHITE, "Editor deselection restores white background")
	check(panel._save_to("res://quack_editor_smoke.tres"), "QUACK saves through Grid Levels")
	panel._new_level()
	panel.request_open(load("res://quack_editor_smoke.tres"))
	check(panel.authoring.level.validate().is_empty(), "Saved QUACK reopens in Grid Levels")
	panel._playtest()
	for frame in range(60): await get_tree().process_frame
	check(EditorInterface.is_playing_scene(), "QUACK launches through editor playtest")
	EditorInterface.stop_playing_scene()
	check(not panel.authoring.level.entities[panel.authoring.level.entities.size() - 1].overrides.has("fed"), "QUACK playtest does not write runtime state into authoring")
