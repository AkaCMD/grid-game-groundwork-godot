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
	await check_camera_navigation(panel)
	await check_paint_height_navigation(panel)
	await check_move_gizmo(panel)
	await check_multi_selection(panel)
	await check_surface_interaction(panel)
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

func camera_mouse(view: GGEditorViewport, button: MouseButton, pressed: bool, point: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.position = point
	view.gui_input.emit(event)

func camera_mouse_input(view: GGEditorViewport, button: MouseButton, pressed: bool, point: Vector2) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_RIGHT if pressed else 0
	event.position = view.get_global_transform_with_canvas() * point
	event.global_position = event.position
	Input.parse_input_event(event)
	await get_tree().process_frame

func check_camera_navigation(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	var entity = GGEntityPlacement.new()
	entity.entity_id = &"camera_fixture"
	entity.definition = fixture.palette[3]
	entity.quarter_turns = 1
	entity.mirrored = true
	fixture.entities.append(entity)
	panel._open(fixture)
	panel._set_mode(0)
	var view = panel.viewport
	view.grab_focus()
	# Advance navigation deterministically, while still routing real key events through the editor.
	view.set_process(false)
	view._yaw = 0.65
	view._pitch = 0.65
	view._camera_position()
	var rotation = view.camera.rotation
	var origin = view.camera.position
	var speed = view._fly_speed
	for binding in [[KEY_W, -view.camera.basis.z], [KEY_S, view.camera.basis.z], [KEY_A, -view.camera.basis.x], [KEY_D, view.camera.basis.x], [KEY_Q, Vector3.DOWN], [KEY_E, Vector3.UP]]:
		origin = view.camera.position
		await mode_key(binding[0])
		view._process(0.25)
		check(view.camera.position.is_equal_approx(origin + binding[1] * speed * 0.25), "WASDQE moves relative to view or world height without a mouse button")
		check(view.camera.rotation.is_equal_approx(rotation), "Flying preserves the view angle")
		await mode_key(binding[0], 0, false, false)
		origin = view.camera.position
		view._process(0.25)
		check(view.camera.position.is_equal_approx(origin), "Releasing a navigation key stops immediately")
	await mode_key(KEY_W)
	await mode_key(KEY_D)
	origin = view.camera.position
	view._process(0.5)
	check(is_equal_approx(view.camera.position.distance_to(origin), speed * 0.5), "Diagonal flight has the same speed as single-axis flight")
	view._stop_navigation()
	origin = view.camera.position
	await mode_key(KEY_W)
	view._process(0.25)
	view._process(0.25)
	check(is_equal_approx(view.camera.position.distance_to(origin), speed * 0.5), "Flight distance depends on elapsed time")
	panel._hover(Vector3i.ZERO)
	check(not view._ghost or not view._ghost.visible, "Navigation hides the placement preview even when hover refreshes")
	var history_size = panel.authoring._history.size()
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, view.size * 0.5)
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, view.size * 0.5)
	check(fixture.entities.size() == 1 and panel.authoring._history.size() == history_size, "Flying cannot paint or change authoring history")
	await mode_key(KEY_ESCAPE)
	check(not view.is_navigating(), "Esc stops keyboard navigation")
	await mode_key(KEY_W, 0, true)
	check(not view.is_navigating(), "Key repeat cannot restart navigation after cancellation")
	for field in [panel._settings_title, panel._height.get_line_edit(), EditorInterface.get_inspector()]:
		field.grab_focus()
		await mode_key(KEY_W)
		check(not view.is_navigating(), "Text, coordinate and Inspector focus do not navigate")
	view.grab_focus()
	await mode_key(KEY_W)
	panel._settings_title.grab_focus()
	check(not view.is_navigating(), "Moving focus out of the viewport stops held navigation")
	view.grab_focus()
	for modifiers in [KEY_MASK_CTRL, KEY_MASK_ALT, KEY_MASK_META]:
		await mode_key(KEY_W, modifiers)
		check(not view.is_navigating(), "Command shortcuts do not move the camera")
	panel._confirm.popup_centered()
	await get_tree().process_frame
	await mode_key(KEY_W)
	check(not view.is_navigating(), "Modal dialogs block camera keys")
	panel._confirm.hide()
	view.grab_focus()
	await mode_key(KEY_W)
	view.get_window().focus_exited.emit()
	check(not view.is_navigating(), "Window focus loss clears held navigation")
	await mode_key(KEY_W)
	panel.hide()
	check(not view.is_navigating(), "Hiding the workspace stops navigation")
	panel.show()
	view.grab_focus()
	view._drawing = true
	await mode_key(KEY_W)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, view.size * 0.5)
	check(not view.is_navigating() and not view._right_pressed, "An active paint stroke blocks keyboard and right-drag navigation")
	view._drawing = false
	view.frame_level()
	var point = view.camera.unproject_position(Vector3.ZERO)
	panel._choose_definition(0)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, point)
	check(panel._definition == fixture.palette[0], "Right press waits before picking or looking")
	camera_mouse(view, MOUSE_BUTTON_RIGHT, false, point)
	check(panel._definition == entity.definition and panel._turns.value == 1 and panel._mirror.button_pressed, "Right click retains definition, rotation and mirroring eyedropper")
	panel._choose_definition(0)
	point = view.camera.unproject_position(Vector3.ZERO)
	await camera_mouse_input(view, MOUSE_BUTTON_RIGHT, true, point)
	check(view._right_pressed, "Real right press reaches the editor viewport")
	await camera_mouse_input(view, MOUSE_BUTTON_RIGHT, false, point)
	check(panel._definition == entity.definition, "Real mouse dispatch retains the right-click eyedropper")
	view._pitch = 0.0
	view._camera_position()
	point = view.camera.unproject_position(Vector3.ZERO)
	check(view.cell_at(point) == null and view.entity_at(point) == entity.entity_id, "A horizontal view can hit an entity without reaching the editing plane")
	panel._choose_definition(0)
	await camera_mouse_input(view, MOUSE_BUTTON_RIGHT, true, point)
	await camera_mouse_input(view, MOUSE_BUTTON_RIGHT, false, point)
	check(panel._definition == entity.definition and panel._turns.value == 1 and panel._mirror.button_pressed, "Horizontal views retain all eyedropper brush settings")
	view._pitch = 0.65
	view._camera_position()
	point = view.camera.unproject_position(Vector3.ZERO)
	panel._choose_definition(0)
	origin = view.camera.position
	rotation = view.camera.rotation
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, point)
	var motion = InputEventMouseMotion.new()
	motion.position = point + Vector2(12, 8)
	motion.relative = Vector2(12, 8)
	motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
	view.gui_input.emit(motion)
	check(view._looking and view.camera.position.is_equal_approx(origin), "Right drag starts free look without orbiting the camera position")
	check(not view.camera.rotation.is_equal_approx(rotation), "Right drag turns the view")
	var zoom = view._zoom
	camera_mouse(view, MOUSE_BUTTON_WHEEL_UP, true, point)
	check(view._fly_speed > speed and view._zoom == zoom, "Right wheel changes movement speed instead of zoom")
	camera_mouse(view, MOUSE_BUTTON_RIGHT, false, point)
	check(not view._looking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and panel._definition == fixture.palette[0], "Finishing a right drag restores the cursor without using the eyedropper")
	camera_mouse(view, MOUSE_BUTTON_WHEEL_UP, true, point)
	check(view._zoom < zoom, "Ordinary wheel still zooms")
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, point)
	camera_mouse(view, MOUSE_BUTTON_WHEEL_DOWN, true, point)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, false, point)
	check(panel._definition == fixture.palette[0], "Right wheel without dragging does not trigger the eyedropper")
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, point)
	view.gui_input.emit(motion)
	await mode_key(KEY_ESCAPE)
	check(not view._looking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Esc restores the captured cursor")
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, point)
	view.gui_input.emit(motion)
	await mode_key(KEY_W)
	await camera_mouse_input(view, MOUSE_BUTTON_RIGHT, false, point)
	check(not view._looking and view.is_navigating(), "Global right release ends free look while direct keyboard movement continues")
	await mode_key(KEY_W, 0, false, false)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, point)
	view.gui_input.emit(motion)
	view.get_window().focus_exited.emit()
	check(not view._looking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Losing window focus restores the captured cursor")
	for global_input in [false, true]:
		camera_mouse(view, MOUSE_BUTTON_RIGHT, true, point)
		motion.button_mask = MOUSE_BUTTON_MASK_RIGHT
		view.gui_input.emit(motion)
		origin = view.camera.position
		rotation = view.camera.rotation
		motion.button_mask = 0
		if global_input: view._input(motion)
		else: view.gui_input.emit(motion)
		check(not view._looking and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "Both input paths recover from a missed right-button release")
		check(view.camera.position.is_equal_approx(origin) and view.camera.rotation.is_equal_approx(rotation), "Mouse motion after a missed release cannot turn the camera")
	view._pitch = -0.5
	view._camera_position()
	origin = view.camera.position
	await mode_key(KEY_W)
	view._process(0.5)
	check(view.camera.position.y > origin.y, "Looking upward and flying forward increases height")
	view._stop_navigation()
	view._look_camera(Vector2(0, -10000))
	check(view.camera.transform.is_finite() and is_zero_approx(view.camera.rotation.z), "Extreme free look stays finite and cannot roll upside down")
	view._fly_speed = speed
	view._yaw = 0.0
	view._pitch = deg_to_rad(75.2)
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	panel._set_mode(0)
	view.set_process(true)

func check_paint_height_navigation(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	panel._open(fixture)
	panel._choose_definition(0)
	panel._height.value = 0
	var view = panel.viewport
	view.grab_focus()
	view.set_process(false)
	await mode_key(KEY_Q)
	# Small frame steps must accumulate rather than rounding each movement away.
	for frame in range(160): view._process(0.01)
	await mode_key(KEY_Q, 0, false, false)
	check(view.layer == -13, "Descending below the original plane moves the paint height with the camera")
	check(panel._height.value == view.layer, "Height control follows the camera's paint plane")
	var point = view.size * 0.5
	var cell = view.cell_at(point)
	check(cell != null and cell.y == -13, "Paint ray still reaches a lower plane after descending below the original height")
	if cell != null:
		var motion = InputEventMouseMotion.new()
		motion.position = point
		view.gui_input.emit(motion)
		check(view._ghost != null and view._ghost.visible and view._ghost.position.y == -13, "Brush preview uses the lowered paint plane")
		camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
		camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
		check(fixture.entities.size() == 1 and fixture.entities[0].cell == cell, "Click paints on the lowered plane")
	var height = view.layer
	view._look_camera(Vector2(12, 10))
	camera_mouse(view, MOUSE_BUTTON_WHEEL_DOWN, true, point)
	check(view.layer == height, "Free look and zoom preserve paint height")
	panel._height.value = -5
	view.grab_focus()
	await mode_key(KEY_E)
	view._process(0.25)
	await mode_key(KEY_E, 0, false, false)
	check(view.layer == -3 and panel._height.value == -3, "Manual height rebases subsequent camera movement")
	var camera_origin = view.camera.position
	await mode_key(KEY_PAGEUP)
	check(view.layer == -2 and panel._height.value == -2, "Page Up raises the paint plane by one cell")
	await mode_key(KEY_PAGEDOWN)
	check(view.layer == -3, "Page Down lowers the paint plane by one cell")
	check(view.camera.position.is_equal_approx(camera_origin), "Paint height shortcuts keep the camera in place")
	await mode_key(KEY_PAGEUP, 0, true)
	check(view.layer == -3, "Paint height shortcuts ignore key repeat")
	panel._settings_title.grab_focus()
	await mode_key(KEY_PAGEUP)
	check(view.layer == -3, "Text fields retain Page Up without changing paint height")
	view.grab_focus()
	view._drawing = true
	await mode_key(KEY_PAGEDOWN)
	check(view.layer == -3, "An active stroke cannot change paint height")
	view._drawing = false
	var pan = InputEventMouseMotion.new()
	pan.position = point
	pan.relative = Vector2(0, 2.75 * view.size.y / (view._zoom * view.camera.global_basis.y.y))
	pan.button_mask = MOUSE_BUTTON_MASK_MIDDLE
	pan.shift_pressed = true
	view.gui_input.emit(pan)
	check(view.layer == 0 and panel._height.value == 0, "Vertical middle pan carries the paint plane and Height control")
	await mode_key(KEY_D)
	view._process(0.25)
	await mode_key(KEY_D, 0, false, false)
	check(view.layer == 0, "Horizontal camera movement preserves the paint height")
	view.set_layer(-80)
	check(panel._height.value == -80, "Automatic height remains synchronized beyond the old spinner limits")
	view.set_layer(0)
	view._yaw = 0.0
	view._pitch = deg_to_rad(75.2)
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	view.set_process(true)

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
	await mode_key(KEY_W)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, view.size * 0.5)
	check(not view.is_navigating() and not view._right_pressed, "An entity drag blocks camera navigation")
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
	check(not view._move_valid and surface_feedback_is(view, GGEditorEntitySurfaces.RED, false), "Solid overlap displays a red invalid preview")
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
	check(duck.get_child(0).material_override.get_shader_parameter("background_color") == Color.WHITE, "Editor selection preserves the opaque white duck background")
	var duck_root: Node3D = board.roots[&"duck_b"]
	check(panel.viewport._surfaces.pick({&"duck_b": duck_root}, duck_root.global_transform * Vector3(0.43, 0.43, 2), duck_root.global_basis * Vector3.FORWARD) == &"duck_b", "QUACK white face background remains opaque to exact mesh picking")
	panel._select(&"duck_c")
	check(duck.get_child(0).material_override.get_shader_parameter("background_color") == Color.WHITE, "Editor deselection retains the original white background")
	panel._select(&"duck_b", true)
	check(duck.get_child(0).material_override.get_shader_parameter("background_color") == Color.WHITE and board.roots[&"duck_c"].get_child(0).get_child(0).material_override.get_shader_parameter("background_color") == Color.WHITE and surface_feedback_is(panel.viewport, GGEditorEntitySurfaces.BLUE, true), "Editor multi-selection uses blue surfaces and preserves every duck background")

	check(panel._save_to("res://quack_editor_smoke.tres"), "QUACK saves through Grid Levels")
	panel._new_level()
	panel.request_open(load("res://quack_editor_smoke.tres"))
	check(panel.authoring.level.validate().is_empty(), "Saved QUACK reopens in Grid Levels")
	panel._playtest()
	for frame in range(60): await get_tree().process_frame
	check(EditorInterface.is_playing_scene(), "QUACK launches through editor playtest")
	EditorInterface.stop_playing_scene()
	check(not panel.authoring.level.entities[panel.authoring.level.entities.size() - 1].overrides.has("fed"), "QUACK playtest does not write runtime state into authoring")

func selection_click(view: GGEditorViewport, cell: Vector3i, shift: bool = false) -> void:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = true
	event.shift_pressed = shift
	event.position = view.camera.unproject_position(Vector3(cell))
	view.gui_input.emit(event)
	event.pressed = false
	view.gui_input.emit(event)

func check_multi_selection(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	for index in range(3):
		var entity = GGEntityPlacement.new()
		entity.entity_id = StringName("member_%d" % index)
		entity.definition = fixture.palette[3]
		entity.cell = Vector3i(index * 3, 2, 0)
		fixture.entities.append(entity)
	panel._open(fixture)
	panel._set_mode(2)
	var view = panel.viewport
	view._yaw = 0.65
	view._pitch = 0.8
	view.frame_level()
	await get_tree().process_frame
	selection_click(view, fixture.entities[0].cell)
	selection_click(view, fixture.entities[1].cell, true)
	check(panel.get("_selection") == [&"member_0", &"member_1"], "Shift-click adds an entity to the selection")
	check(view._move_gizmo.position == Vector3(3, 2, 0), "Gizmo follows the last selected entity")
	selection_click(view, fixture.entities[1].cell, true)
	check(panel.get("_selection") == [&"member_0"], "Shift-click removes a selected entity")
	check(view._move_gizmo.position == Vector3(0, 2, 0), "Removing the active entity restores the preceding selection anchor")
	selection_click(view, Vector3i(-3, 2, 0), true)
	check(panel.get("_selection") == [&"member_0"], "Shift-click on empty space preserves selection")
	selection_click(view, fixture.entities[2].cell)
	check(panel.get("_selection") == [&"member_2"], "Plain click replaces selection")
	selection_click(view, Vector3i(-3, 2, 0))
	check(panel.get("_selection") == [], "Plain click on empty space clears selection")
	selection_click(view, fixture.entities[0].cell)
	selection_click(view, fixture.entities[1].cell, true)
	check(view._surfaces.highlights.size() == 2, "Every selected entity has a highlight")
	check(panel._entity_label.text == "2 entities selected" and not panel._coords[0].editable and not panel._entity_turns.editable and panel._entity_mirror.disabled, "Multi-selection shows count and disables single-entity fields")
	check(panel._apply_button.disabled and panel._reset_button.disabled and panel._inspector.get_edited_object() == null, "Multi-selection disables overrides and Apply")
	await mode_key(KEY_END)
	check(fixture.entities[0].cell == Vector3i(0, 2, 0) and fixture.entities[1].cell == Vector3i(3, 2, 0), "End does not snap one member of a multi-selection")
	var grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	check(view.board.roots[&"member_0"].position == Vector3(1, 2, 0) and view.board.roots[&"member_1"].position == Vector3(4, 2, 0), "Whole group follows the move preview with preserved spacing")
	check(fixture.entities[0].cell == Vector3i(0, 2, 0), "Group preview does not modify authored coordinates")
	gizmo_release(panel, grabbed + Vector3.RIGHT)
	check(fixture.entities[0].cell == Vector3i(1, 2, 0) and fixture.entities[1].cell == Vector3i(4, 2, 0), "Release commits every selected entity")
	check(panel.authoring.undo() and fixture.entities[0].cell == Vector3i(0, 2, 0) and fixture.entities[1].cell == Vector3i(3, 2, 0), "Editor group drag is one undo action")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3(3, 0, 0))
	check(not view._move_valid, "One blocked member invalidates the group preview")
	check(surface_feedback_is(view, GGEditorEntitySurfaces.RED, false), "Every selected surface becomes steady red on collision")
	gizmo_release(panel, grabbed + Vector3(3, 0, 0))
	check(fixture.entities[0].cell == Vector3i(0, 2, 0) and fixture.entities[1].cell == Vector3i(3, 2, 0), "Invalid release restores the entire group")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	await mode_key(KEY_ESCAPE)
	check(view.board.roots[&"member_0"].position == Vector3(0, 2, 0) and view.board.roots[&"member_1"].position == Vector3(3, 2, 0), "Esc restores every member's visual position")
	panel._duplicate()
	check(fixture.entities.size() == 5 and panel._selection.size() == 2 and not panel._selection.has(&"member_0") and not panel._selection.has(&"member_1"), "Duplicate selects the new group")
	var copies = panel._selection.duplicate()
	panel._delete_selected()
	check(fixture.entities.size() == 3 and panel._selection.is_empty(), "Delete removes the entire group and clears selection")
	check(panel.authoring.undo() and fixture.entities.size() == 5 and panel._selection.is_empty(), "Undo restores deleted entities without changing selection")
	check(panel.authoring.undo() and fixture.entities.size() == 3, "A second undo removes the duplicate group")
	check(panel.authoring.redo() and panel.authoring.find_entity(copies[0]) != null, "Redo restores copies with stable IDs")
	selection_click(view, fixture.entities[0].cell)
	check(panel._coords[0].editable and not panel._apply_button.disabled and panel._inspector.get_edited_object() != null, "Returning to one selection restores single-entity editing")
	panel._shape_mode.button_pressed = true
	check(panel._selection.is_empty() and not view._move_gizmo.visible, "Entering shape editing clears selection")
	panel._shape_mode.button_pressed = false
	view._pitch = 0.0
	view._pivot = Vector3(3, 2, 0)
	view._camera_position()
	await get_tree().process_frame
	selection_click(view, fixture.entities[0].cell, true)
	selection_click(view, fixture.entities[1].cell, true)
	check(panel._selection == [&"member_0", &"member_1"], "Visible entities can be selected when the view ray cannot reach the placement plane")
	panel._open(previous)
	check(panel._selection.is_empty(), "Opening another level clears selection")
	panel._choose_definition(previous.palette.find(definition))
	panel._set_mode(0)

func surface_feedback_is(view: GGEditorViewport, color: Color, breathing: bool) -> bool:
	if view._surfaces.highlights.is_empty(): return false
	for overlay in view._surfaces.highlights:
		for surface in range(overlay.mesh.get_surface_count()):
			var material = overlay.get_surface_override_material(surface)
			if material.get_shader_parameter("tint") != color or material.get_shader_parameter("breathing") != breathing:
				return false
	return true

func check_surface_interaction(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	var marker = GGEntityPlacement.new()
	marker.entity_id = &"surface_ring"
	marker.definition = fixture.palette[4]
	marker.definition = marker.definition.duplicate(true)
	marker.definition.solid = false
	marker.definition.visual_scene = null
	var behind = GGEntityPlacement.new()
	behind.entity_id = &"surface_behind"
	behind.definition = fixture.palette[3]
	behind.cell = Vector3i(0, -2, 0)
	fixture.entities.assign([marker, behind])
	panel._open(fixture)
	panel._set_mode(2)
	var view = panel.viewport
	view._pitch = PI / 2.0
	view._yaw = 0.0
	view._pivot = Vector3.ZERO
	view._zoom = 8.0
	view._camera_position()
	await get_tree().process_frame
	var center = view.camera.unproject_position(Vector3.ZERO)
	var rim = view.camera.unproject_position(Vector3(0.30, -0.43, 0.05))
	check(view.entity_at(center) == behind.entity_id, "Exact model picking passes through the ring hole to the visible entity behind")
	check(view.entity_at(rim) == marker.entity_id, "Exact model picking hits the ring surface in front")
	var root: Node3D = view.board.roots[marker.entity_id]
	var nested = Node3D.new()
	root.add_child(nested)
	nested.rotation.y = PI / 2.0
	nested.scale = Vector3(-1.0, 1.0, 2.0)
	var box = BoxMesh.new()
	box.size = Vector3.ONE * 0.25
	var protrusion = GGBoardView.mesh_node(box, Color.WHITE, Vector3(0, 0, 0.65))
	nested.add_child(protrusion)
	var outside = view.camera.unproject_position(protrusion.global_position)
	check(view.entity_at(outside) == marker.entity_id, "Picking follows mirrored, rotated, scaled nested meshes outside occupied cells")
	protrusion.hide()
	check(view.entity_at(outside) == &"", "Hidden meshes do not participate in picking")
	protrusion.show()
	panel._select(marker.entity_id)
	check(view._surfaces.highlights.size() == 2 and surface_feedback_is(view, GGEditorEntitySurfaces.BLUE, true), "Every visible mesh of a selected entity breathes blue")
	for overlay in view._surfaces.highlights:
		check(overlay.mesh == overlay.get_parent().mesh and overlay.transform == Transform3D.IDENTITY, "Highlights follow exact source geometry and local transforms")
	var authored_material = root.get_child(0).material_override
	view.preview_move(marker.cell + Vector3i.RIGHT, false)
	check(surface_feedback_is(view, GGEditorEntitySurfaces.RED, false), "Invalid preview uses steady red surfaces")
	view.preview_move(marker.cell, true)
	check(surface_feedback_is(view, GGEditorEntitySurfaces.BLUE, true), "Returning to a valid preview restores blue breathing")
	check(root.get_child(0).material_override == authored_material, "Surface feedback preserves original entity materials")
	panel._set_mode(1)
	view._update_erase_hover(rim)
	check(view._erase_target == marker.entity_id and surface_feedback_is(view, GGEditorEntitySurfaces.RED, true), "Erase hover breathes red on precisely the entity under the pointer")
	check(panel._selection == [marker.entity_id], "Erase mode preserves the recorded selection")
	view._update_erase_hover(center)
	check(view._erase_target == behind.entity_id and view._surfaces.highlights[0].get_parent().get_parent() == view.board.roots[behind.entity_id], "Hover through a model hole highlights the actual deletion target")
	view.mouse_exited.emit()
	check(view._surfaces.highlights.is_empty(), "Leaving the viewport clears erase feedback without showing blue selection")
	panel._set_mode(2)
	check(surface_feedback_is(view, GGEditorEntitySurfaces.BLUE, true), "Returning to Select restores blue feedback")
	# A true alpha cutout passes through; custom shader sprite alpha is not assumed transparent.
	var quad = MeshInstance3D.new()
	quad.mesh = QuadMesh.new()
	quad.rotation.x = -PI / 2.0
	quad.position.y = 1.0
	var pixels = Image.create(2, 1, false, Image.FORMAT_RGBA8)
	pixels.set_pixel(0, 0, Color(1, 1, 1, 0))
	pixels.set_pixel(1, 0, Color.WHITE)
	var cutout = StandardMaterial3D.new()
	cutout.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	cutout.albedo_texture = ImageTexture.create_from_image(pixels)
	quad.material_override = cutout
	root.add_child(quad)
	var clear_pixel = view.camera.unproject_position(Vector3(-0.1, 1, 0))
	var opaque_pixel = view.camera.unproject_position(Vector3(0.1, 1, 0))
	check(view.entity_at(clear_pixel) == behind.entity_id, "Actual transparent material pixels pass through to the visible model behind")
	check(view.entity_at(opaque_pixel) == marker.entity_id, "Opaque material pixels remain pickable")
	quad.free()
	# Deletion and drag use the same geometry target, even inside one placement cell.
	panel._set_mode(1)
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, rim)
	check(panel.authoring.find_entity(marker.entity_id) == null and panel.authoring.find_entity(behind.entity_id) != null, "Erase click removes exactly the red-hovered entity")
	var motion = InputEventMouseMotion.new()
	motion.position = center
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	view.gui_input.emit(motion)
	check(panel.authoring.find_entity(behind.entity_id) == null, "Erase drag can change model targets within the same placement cell")
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, center)
	check(panel.authoring.undo() and fixture.entities.size() == 2, "The geometry-based erase stroke remains one undo action")
	view._pitch = 0.0
	view._pivot = Vector3(0, -2, 0)
	view._camera_position()
	center = view.camera.unproject_position(Vector3(0, -2, 0))
	view._update_erase_hover(center)
	check(view.cell_at(center) == null and view._erase_target == behind.entity_id, "Erase hover works when the ray cannot reach the edit plane")
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, center)
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, center)
	check(panel.authoring.find_entity(behind.entity_id) == null, "Horizontal-view deletion matches the visible red-hovered entity")
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	panel._set_mode(0)
