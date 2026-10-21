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
	await check_workspace_layout(panel)
	await check_workspace_shortcuts(panel)
	await check_text_dialogs(panel)
	await check_inspector_selection_refresh(panel)
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
	await check_paint_surfaces(panel)
	await check_paint_mode_preview(panel)
	await check_move_gizmo(panel)
	await check_multi_selection(panel)
	await check_selection_height(panel)
	await check_paint_height_offset(panel)
	await check_auto_lift_height_offset(panel)
	await check_surface_interaction(panel)
	await check_end_snap(panel)
	panel._shape_mode.button_pressed = true
	panel.stroke.begin()
	panel.stroke.sample(Vector3(1, 10, 0), Vector3.DOWN, 0)
	panel.stroke.finish()
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

func inspector_edit(resource: Resource, property: String, value: Variant, panel: GGEditorPanel) -> void:
	EditorInterface.edit_resource(resource)
	await get_tree().process_frame
	var inspector = EditorInterface.get_inspector()
	check(inspector.get_edited_object() == resource, "Native Inspector targets the authored resource")
	resource.set(property, value)
	# Reproduce the native Inspector's notification, rather than invoking
	# selection.reconcile or the panel's refresh helpers from the test.
	inspector.property_edited.emit(property)
	check(panel._definition_refresh_pending, "Inspector edit schedules the panel refresh without authoring.changed")
	for frame in range(2): await get_tree().process_frame

func check_inspector_selection_refresh(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var view = panel.viewport
	var camera_state = [view._pivot, view._yaw, view._pitch, view._zoom]
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	var entity = GGEntityPlacement.new()
	entity.entity_id = &"inspector_selection"
	entity.definition = fixture.palette[3]
	entity.quarter_turns = 1
	entity.mirrored = true
	entity.overrides = {"weight": 7.0}
	fixture.entities.append(entity)
	panel._open(fixture)
	panel._set_mode(2)
	panel._select(entity.entity_id)
	await inspector_edit(entity, "cell", Vector3i(5, 0, 0), panel)
	check(entity.cell == Vector3i(5, 0, 0) and panel.selection.position() == entity.cell, "Inspector cell edit reconciles the selected movement anchor")
	check(view.board.roots[entity.entity_id].position == Vector3(entity.cell) and view._move_gizmo.position == Vector3(entity.cell), "Inspector refresh keeps the model and gizmo at the authored cell")
	check(panel._coords[0].value == 5 and panel.authoring.dirty, "Inspector refresh updates coordinate fields and dirty state")
	view._pivot = Vector3(5, 0, 0)
	view._yaw = 0.65
	view._pitch = 0.65
	view._zoom = 12.0
	view._camera_position()
	view.grab_focus()
	await get_tree().process_frame
	var history_size = panel.authoring._history.size()
	var grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	check(panel.selection.position() == Vector3i(6, 0, 0) and entity.cell == Vector3i(5, 0, 0), "Drag after Inspector refresh previews from the new anchor without changing authored data")
	gizmo_release(panel, grabbed + Vector3.RIGHT)
	check(entity.cell == Vector3i(6, 0, 0) and panel.authoring._history.size() == history_size + 1, "Drag after Inspector edit commits exactly one authoring action")
	check(panel.authoring.undo() and panel.authoring.find_entity(entity.entity_id).cell == Vector3i(5, 0, 0), "One undo restores the Inspector-authored cell")
	check(panel.authoring.redo() and panel.authoring.find_entity(entity.entity_id).cell == Vector3i(6, 0, 0), "Redo restores the accepted move after Inspector editing")
	# History restores placements from copies; inspect the current resource.
	entity = panel.authoring.find_entity(entity.entity_id)
	check(entity.quarter_turns == 1 and entity.mirrored and entity.overrides == {"weight": 7.0}, "Inspector refresh and movement preserve orientation and overrides")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	history_size = panel.authoring._history.size()
	await inspector_edit(entity, "cell", Vector3i(8, 0, 0), panel)
	check(not panel.selection.is_moving() and view._move_gizmo.active_handle == -1, "Inspector refresh cancels a stale selection preview and gizmo drag")
	check(panel.selection.position() == entity.cell and view.board.roots[entity.entity_id].position == Vector3(entity.cell) and view._move_gizmo.position == Vector3(entity.cell), "Cancelling stale preview retains the externally edited position")
	gizmo_release(panel, grabbed + Vector3.RIGHT)
	check(entity.cell == Vector3i(8, 0, 0) and panel.authoring._history.size() == history_size, "Release after Inspector cancellation cannot commit the stale preview")
	panel.selection.begin_move()
	panel.selection.preview_move(Vector3i(10, 0, 0))
	await inspector_edit(entity, "entity_id", &"renamed_selection", panel)
	check(panel.selection.ids().is_empty() and panel.selection.positions().is_empty() and not panel.selection.is_moving(), "Inspector Entity ID change cancels preview and prunes the invalid selection")
	check(not view._move_gizmo.visible and view.board.roots.has(entity.entity_id) and not panel._coords[0].editable, "Renamed entity rebuilds with no stale gizmo or editable selection fields")
	panel._select(entity.entity_id)
	panel.selection.begin_move()
	panel.selection.preview_move(Vector3i(10, 0, 0))
	var empty_entities: Array[GGEntityPlacement] = []
	await inspector_edit(fixture, "entities", empty_entities, panel)
	check(panel.selection.ids().is_empty() and not panel.selection.is_moving() and view.board.roots.is_empty() and not view._move_gizmo.visible, "Inspector deletion removes invalid selection and cancels its preview")
	check(panel.authoring._history.size() == history_size, "Inspector reconciliation never records an authoring move")
	EditorInterface.get_inspector().edit(null)
	panel._open(previous)
	panel._set_mode(0)
	view._pivot = camera_state[0]
	view._yaw = camera_state[1]
	view._pitch = camera_state[2]
	view._zoom = camera_state[3]
	view._camera_position()
	print("INSPECTOR_SELECTION_SMOKE completed")

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

func focus_control(panel: GGEditorPanel, control: Control) -> void:
	# Property fields now live on separate tabs; focus the visible field as a user would.
	for index in range(panel._tabs.get_tab_count()):
		if panel._tabs.get_tab_control(index).is_ancestor_of(control):
			panel._tabs.current_tab = index
	control.grab_focus()

func check_workspace_layout(panel: GGEditorPanel) -> void:
	EditorInterface.set_main_screen_editor("Grid Levels")
	await get_tree().process_frame
	panel._tool_buttons[1].pressed.emit()
	check(panel._mode == 1 and not panel._brush_controls.visible, "Erase button switches tools and hides irrelevant brush controls")
	panel._tool_buttons[0].pressed.emit()
	check(panel._mode == 0 and panel._brush_controls.visible, "Paint button restores brush controls")
	panel._tabs.current_tab = 1
	panel._settings_title.text = "Draft title"
	panel._tabs.current_tab = 0
	panel._tabs.current_tab = 1
	check(panel._settings_title.text == "Draft title" and panel.authoring.level.title != "Draft title", "Switching property tabs preserves unapplied settings without committing them")
	panel._floor_height.value = -3
	check(panel._height.value == -3 and panel.viewport.layer == -3, "Floor height edits change the shared placement plane")
	panel._height.value = 0
	check(panel._floor_height.value == 0, "Toolbar height edits synchronize the floor controls")
	panel._set_status("Validation result must remain visible")
	panel._hover(Vector3i(3, 0, 4))
	check(panel._status.text == "Validation result must remain visible" and panel._pointer_status.text.contains("(3, 0, 4)"), "Pointer feedback cannot overwrite operation results")
	panel._set_mode(2)
	panel._shape_mode.button_pressed = true
	check(panel._mode == 0 and panel._shape_banner.visible and panel._tool_buttons[2].disabled, "Shape entry explains its scope and switches Select to a supported tool")
	check(panel._tabs.current_tab == 0 and panel._tabs.is_tab_disabled(1), "Shape editing keeps unrelated level operations out of the current context")
	panel._shape_mode.button_pressed = false
	check(not panel._shape_banner.visible and not panel._tabs.is_tab_disabled(1), "Returning to level restores authoring controls")
	check(panel._duplicate_button.disabled and panel._delete_button.disabled and not panel._single_entity.visible, "Empty selection offers guidance instead of unusable entity controls")
	panel._sync_play_state()
	check(panel._stop_button.disabled, "Stop is disabled when no scene is running")
	panel._new_level()

func check_workspace_shortcuts(panel: GGEditorPanel) -> void:
	for screen in ["3D", "2D"]:
		EditorInterface.set_main_screen_editor(screen)
		EditorInterface.get_inspector().grab_focus()
		await get_tree().process_frame
		EditorInterface.set_main_screen_editor("Grid Levels")
		await get_tree().process_frame
		for binding in [[KEY_2, 1], [KEY_3, 2], [KEY_1, 0]]:
			await mode_key(binding[0])
			check(panel._mode == binding[1], "Entering Grid Levels enables number shortcuts without a canvas click")

func check_mode_shortcuts(panel: GGEditorPanel) -> void:
	panel.viewport.grab_focus()
	for binding in [[KEY_2, 1], [KEY_3, 2], [KEY_1, 0], [KEY_KP_2, 1], [KEY_KP_3, 2], [KEY_KP_1, 0]]:
		await mode_key(binding[0])
		check(panel._mode == binding[1], "Number row and keypad switch authoring modes")
	if await pointer_motion(panel.viewport, panel.viewport.size * 0.5):
		pointer_key(panel.viewport, KEY_2)
		if pointer_valid(panel.viewport, panel.viewport.size * 0.5, "Erase shortcut"):
			check(not panel.viewport._ghost.visible, "Erase immediately hides the brush preview")
		pointer_key(panel.viewport, KEY_1)
		if pointer_valid(panel.viewport, panel.viewport.size * 0.5, "Paint shortcut"):
			check(panel.viewport._ghost.visible, "Paint immediately restores the brush preview")
	for modifiers in [KEY_MASK_CTRL, KEY_MASK_ALT, KEY_MASK_SHIFT, KEY_MASK_META]:
		await mode_key(KEY_2, modifiers)
		check(panel._mode == 0, "Modified number keys do not switch modes")
	await mode_key(KEY_2, 0, true)
	await mode_key(KEY_2, 0, false, false)
	check(panel._mode == 0, "Key repeat and release do not switch modes")
	focus_control(panel, panel._settings_title)
	await mode_key(KEY_2)
	check(panel._mode == 0, "Title entry does not switch modes")
	panel._height.get_line_edit().grab_focus()
	await mode_key(KEY_KP_2)
	check(panel._mode == 0, "Coordinate entry does not switch modes")
	panel._mirror.grab_focus()
	await mode_key(KEY_2)
	check(panel._mode == 1, "Shortcuts work outside the canvas within the panel")
	# Do not refocus between presses: hiding Mirror brush used to clear focus
	# after the first switch and silently reject every subsequent shortcut.
	for binding in [[KEY_1, 0], [KEY_3, 2], [KEY_KP_1, 0]]:
		await mode_key(binding[0])
		check(panel._mode == binding[1], "Consecutive shortcuts survive hiding the focused brush controls")
	panel._mirror.grab_focus()
	for binding in [[KEY_KP_3, 2], [KEY_KP_2, 1], [KEY_1, 0], [KEY_2, 1]]:
		await mode_key(binding[0])
		check(panel._mode == binding[1], "Keypad shortcuts also retain focus after leaving Paint")
	panel._confirm.popup_centered()
	await get_tree().process_frame
	await mode_key(KEY_3)
	check(panel._mode == 1, "Modal dialogs block mode shortcuts")
	panel._confirm.hide()
	panel.viewport.grab_focus()
	panel.stroke.begin()
	await mode_key(KEY_3)
	check(panel._mode == 1, "An active stroke blocks mode shortcuts")
	panel.stroke.finish()
	await mode_key(KEY_3)
	check(panel._mode == 2, "Switching resumes after the stroke")
	panel._shape_mode.button_pressed = true
	await mode_key(KEY_1)
	await mode_key(KEY_3)
	check(panel._mode == 0, "Shape editing ignores Select")
	await mode_key(KEY_2)
	check(panel._mode == 1, "Shape editing supports Erase")
	await mode_key(KEY_1)
	check(panel._mode == 0, "Shape editing supports Paint")
	panel._shape_mode.button_pressed = false
	check(panel._mode == 2, "Leaving shape editing restores the previous level tool")
	panel._set_mode(0)
	panel.hide()
	await mode_key(KEY_2)
	check(panel._mode == 0, "Hidden panel ignores mode shortcuts")
	panel.show()
	EditorInterface.get_inspector().grab_focus()
	await mode_key(KEY_2)
	check(panel._mode == 0, "Focus outside the panel ignores mode shortcuts")
	panel.viewport.grab_focus()
	await check_context_focus(panel)

func check_context_focus(panel: GGEditorPanel) -> void:
	panel._set_mode(2)
	var ids = panel.authoring.level.entities.map(func(entity): return entity.entity_id)
	panel._select(ids[0])
	focus_control(panel, panel._entity_mirror)
	panel._select(ids[1], true)
	check(not panel._single_entity.visible, "Multi-selection hides the focused single-entity controls")
	for binding in [[KEY_1, 0], [KEY_2, 1], [KEY_3, 2]]:
		await mode_key(binding[0])
		check(panel._mode == binding[1], "Shortcuts survive hiding single-entity controls")
	panel._delete_button.grab_focus()
	await mode_key(KEY_DELETE)
	check(not panel._selection_actions.visible, "Deleting from a focused selection action hides that action")
	for binding in [[KEY_1, 0], [KEY_3, 2]]:
		await mode_key(binding[0])
		check(panel._mode == binding[1], "Shortcuts survive hiding the focused selection actions")
	panel.authoring.undo()
	focus_control(panel, panel._settings_title)
	panel._shape_mode.button_pressed = true
	check(panel.get_viewport().gui_get_focus_owner() == panel.viewport, "Shape entry transfers focus before hiding the Level tab")
	var back = find_button(panel._shape_banner, "Return to level")
	back.grab_focus()
	back.pressed.emit()
	for binding in [[KEY_1, 0], [KEY_2, 1], [KEY_3, 2]]:
		await mode_key(binding[0])
		check(panel._mode == binding[1], "Returning from the focused shape banner preserves consecutive shortcuts")
	panel._set_mode(0)

func find_button(node: Node, text: String) -> Button:
	if node is Button and node.text == text: return node
	for child in node.get_children():
		var button = find_button(child, text)
		if button: return button
	return null

func settle_layout() -> void:
	for frame in range(5): await get_tree().process_frame

func check_dialog_body(dialog: AcceptDialog, body: RichTextLabel, last_line: String, must_scroll: bool = false) -> void:
	await settle_layout()
	var usable = Rect2i(get_viewport().get_visible_rect()) if dialog.is_embedded() else Rect2i(get_window().position, get_window().size)
	check(usable.encloses(Rect2i(dialog.position, dialog.size)), "Text popup fits inside its parent window or embedder")
	if not dialog.is_embedded() and DisplayServer.get_name() != "headless":
		check(DisplayServer.screen_get_usable_rect(dialog.current_screen).encloses(Rect2i(dialog.position, dialog.size)), "Native popup stays within the usable screen")
	check(dialog.size.x <= get_window().size.x and dialog.size.y <= get_window().size.y, "Text popup stays within the editor window dimensions")
	check(Rect2(Vector2.ZERO, Vector2(dialog.size)).encloses(dialog.get_ok_button().get_global_rect()), "Dialog OK button stays accessible")
	check(body.text.ends_with(last_line), "The complete final line is preserved in the scrollable body")
	var bar = body.get_v_scroll_bar()
	if must_scroll or body.get_content_height() > body.size.y:
		check(bar.visible and bar.max_value > bar.page, "Overflowing dialog text has an active vertical scrollbar")
	check(is_zero_approx(bar.value), "Opening a text dialog starts at the first line")
	body.scroll_to_line(body.get_line_count() - 1)
	await settle_layout()
	check(is_equal_approx(bar.value, maxf(0, bar.max_value - bar.page)), "Scrolling reaches the final line of the full text")
	var screenshot = OS.get_environment("GGG_EDITOR_SCREENSHOT")
	if DisplayServer.get_name() != "headless" and not screenshot.is_empty():
		var suffix = "details" if dialog.title == "Operation result" else "help"
		var image = dialog.get_texture().get_image()
		image.save_png(screenshot.get_basename() + "-%s-%d.png" % [suffix, get_window().size.y])
	dialog.hide()
	await settle_layout()

func check_text_dialogs(panel: GGEditorPanel) -> void:
	var window = get_window()
	var previous_size = window.size
	var previous_min_size = window.min_size
	var previous_mode = window.mode
	var distraction_free = EditorInterface.distraction_free_mode
	EditorInterface.distraction_free_mode = true
	window.mode = Window.MODE_WINDOWED
	# Godot scales its own window minimum to 1536×900 at 150%. Relax it only
	# for this test so the requested 1024×600 popup constraint is exercised.
	window.min_size = Vector2i.ZERO
	var messages = PackedStringArray()
	for index in range(80):
		messages.append("Entity crate_%d has an invalid overlapping solid cell at (1, 0, 0)." % index)
	var complete = "\n".join(messages)
	for dimensions in [Vector2i(1440, 940), Vector2i(1024, 600)]:
		window.size = dimensions
		await settle_layout()
		check(window.size == dimensions, "Dialog regression runs at the requested compact window size")
		panel._set_status("Short result")
		await settle_layout()
		var canvas_rect = panel.viewport.get_global_rect()
		panel._set_status(complete)
		panel._hover(Vector3i(3, 0, 4))
		await settle_layout()
		check(panel._status.tooltip_text == complete and not panel._status.text.contains("\n"), "Long diagnostics retain a complete tooltip and a single-line status")
		check(panel._pointer_status.text.contains("(3, 0, 4)"), "Live coordinates stay independent of long operation results")
		check(panel.viewport.get_global_rect() == canvas_rect, "Long feedback does not resize or move the canvas")
		find_button(panel, "Details").pressed.emit()
		var mode = panel._mode
		await mode_key(KEY_3)
		check(panel._mode == mode, "Details remains modal to authoring shortcuts")
		check(panel._status_text.text == complete, "Details contains every diagnostic without truncation")
		await check_dialog_body(panel._status_detail, panel._status_text, messages[-1], true)
		check(panel.viewport.get_global_rect() == canvas_rect, "Opening and scrolling Details leaves the canvas unchanged")
		# Reopen after scrolling: the next read must start at the first result.
		find_button(panel, "Details").pressed.emit()
		await settle_layout()
		check(is_zero_approx(panel._status_text.get_v_scroll_bar().value), "Reopening Details resets its scroll position")
		panel._status_detail.hide()
		find_button(panel, "Help").pressed.emit()
		await mode_key(KEY_2)
		check(panel._mode == mode, "Help remains modal to authoring shortcuts")
		await check_dialog_body(panel._help, panel._help_text, "WASD / arrows: move    •    Z / Y / R: undo / redo / restart")
		check(panel.viewport.get_global_rect() == canvas_rect, "Opening and scrolling Help leaves the canvas unchanged")
		print("EDITOR_DIALOGS: scale=", panel._scale, " window=", window.size, " details=", panel._status_detail.size, " help=", panel._help.size)
	window.min_size = previous_min_size
	window.size = previous_size
	window.mode = previous_mode
	EditorInterface.distraction_free_mode = distraction_free
	panel.viewport.grab_focus()
	await settle_layout()

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
	# Direct Q/E flight remains available outside Paint and selected Select.
	panel._set_mode(1)
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
	panel._set_mode(0)
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
		focus_control(panel, field)
		await mode_key(KEY_W)
		check(not view.is_navigating(), "Text, coordinate and Inspector focus do not navigate")
	view.grab_focus()
	await mode_key(KEY_W)
	focus_control(panel, panel._settings_title)
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
	# Let native hover and container layout settle before beginning another gesture.
	for frame in range(2): await get_tree().process_frame
	view.grab_focus()
	panel.stroke.begin()
	await mode_key(KEY_W)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, view.size * 0.5)
	check(not view.is_navigating() and not view._right_pressed, "An active paint stroke blocks keyboard and right-drag navigation")
	panel.stroke.finish()
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
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, view.size * 0.5)
	await mode_key(KEY_Q)
	# Small frame steps must accumulate rather than rounding each movement away.
	for frame in range(160): view._process(0.01)
	await mode_key(KEY_Q, 0, false, false)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, false, view.size * 0.5)
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
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, view.size * 0.5)
	await mode_key(KEY_E)
	view._process(0.25)
	await mode_key(KEY_E, 0, false, false)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, false, view.size * 0.5)
	check(view.layer == -3 and panel._height.value == -3, "Manual height rebases subsequent camera movement")
	var camera_origin = view.camera.position
	await mode_key(KEY_PAGEUP)
	check(view.layer == -2 and panel._height.value == -2, "Page Up raises the paint plane by one cell")
	await mode_key(KEY_PAGEDOWN)
	check(view.layer == -3, "Page Down lowers the paint plane by one cell")
	check(view.camera.position.is_equal_approx(camera_origin), "Paint height shortcuts keep the camera in place")
	await mode_key(KEY_PAGEUP, 0, true)
	check(view.layer == -3, "Paint height shortcuts ignore key repeat")
	focus_control(panel, panel._settings_title)
	await mode_key(KEY_PAGEUP)
	check(view.layer == -3, "Text fields retain Page Up without changing paint height")
	view.grab_focus()
	panel.stroke.begin()
	await mode_key(KEY_PAGEDOWN)
	check(view.layer == -3, "An active stroke cannot change paint height")
	panel.stroke.finish()
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
			check(panel.selection.position() == original, "Sub-half-cell pointer motion stays snapped to the original cell")
			gizmo_motion(panel, grabbed + offsets[handle])
			var target = original + Vector3i(offsets[handle])
			check(panel.selection.position() == target, "Handle %d snaps only its active axes" % handle)
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
	for frame in range(2): await get_tree().process_frame
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	for frame in range(4): await get_tree().process_frame
	var valid_rect = view.get_global_rect()
	var valid_status_height = panel._status.size.y
	gizmo_motion(panel, grabbed + Vector3(3, 0, 0))
	for frame in range(4): await get_tree().process_frame
	check(view.get_global_rect() == valid_rect and panel._status.size.y == valid_status_height, "Invalid destination status must not resize or move the editing viewport")
	check(panel._status.tooltip_text.contains("Invalid destination:") and panel._status.tooltip_text.contains("Release to restore"), "Full invalid destination details remain available in the tooltip: %s (moving=%s, position=%s)" % [panel._status.tooltip_text, view.is_moving(), panel.selection.position()])
	check(not panel.selection.is_valid() and surface_feedback_is(view, GGEditorEntitySurfaces.RED, false), "Solid overlap displays a red invalid preview")
	gizmo_release(panel, grabbed + Vector3(3, 0, 0))
	check(panel.authoring.find_entity(entity.entity_id).cell == original and view.board.roots[entity.entity_id].position == Vector3(original), "Invalid release restores the starting position")
	check(panel.authoring._history.size() == history_size, "Invalid release does not add undo actions")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3(6, 0, 0))
	check(panel.selection.is_valid(), "Dragging across an obstacle to free cells is permitted")
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
		var before_snap = panel.selection.position()
		history_size = panel.authoring._history.size()
		await mode_key(KEY_END)
		var snapped = Vector3i(before_snap.x, 0, before_snap.z)
		check(view.is_moving() and view._move_gizmo.active_handle == handle and panel.selection.position() == snapped, "End snaps preview while retaining handle %d" % handle)
		check(panel.authoring.find_entity(entity.entity_id).cell == original and panel.authoring._history.size() == history_size, "Mid-drag End does not commit or add history")
		check(view._move_gizmo.target_at(view._move_pointer) == snapped, "Pointer anchor rebases after End without jumping back")
		for axis in range(3): check(int(panel._coords[axis].value) == snapped[axis], "Coordinates follow the grounded preview")
		var anchor = view._move_gizmo._start_hit
		var delta: Vector3 = view._move_gizmo.MASKS[handle]
		gizmo_motion(panel, anchor + delta)
		var final_cell = snapped + Vector3i(delta)
		check(panel.selection.position() == final_cell, "Continued dragging retains its axis/plane constraint after End")
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
	var invalid = panel.selection.position()
	await mode_key(KEY_END)
	check(not panel.selection.is_valid() and panel.selection.position() == invalid and panel._status.text.contains("overlapping"), "End rejects an overlapping preview without changing it")
	await mode_key(KEY_ESCAPE)
	# Outside the authored floor, there is no invisible Y=0 fallback.
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3(20, 0, 0))
	var unsupported = panel.selection.position()
	history_size = panel.authoring._history.size()
	await mode_key(KEY_END)
	check(panel.selection.position() == unsupported and panel._status.text.contains("No supporting surface"), "End over a gap keeps the preview in place and explains why")
	check(panel.authoring._history.size() == history_size, "Failed End adds no history")
	await mode_key(KEY_ESCAPE)
	# End must continue to work as a text-navigation key in input fields.
	for focus in [panel._settings_title, panel._coords[0].get_line_edit()]:
		focus_control(panel, focus)
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

func check_selection_height(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	for index in range(3):
		var entity = GGEntityPlacement.new()
		entity.entity_id = StringName("height_%d" % index)
		entity.definition = fixture.palette[3]
		entity.cell = Vector3i(0, [2, 3, 5][index], 0)
		entity.quarter_turns = 1
		entity.mirrored = true
		entity.overrides = {"weight": 7}
		fixture.entities.append(entity)
	panel._open(fixture)
	panel._set_mode(2)
	panel._select(&"height_1")
	var view = panel.viewport
	view.grab_focus()
	view.set_process(false)
	var camera_origin = view.camera.position
	var paint_height = view.layer
	var history_size = panel.authoring._history.size()
	await mode_key(KEY_E)
	check(panel.authoring.find_entity(&"height_1").cell.y == 4, "E raises a single selection by one cell")
	check(view._move_gizmo.position.y == 4 and panel._coords[1].value == 4 and view.board.roots[&"height_1"].position.y == 4, "Keyboard movement refreshes the gizmo, coordinates and visual")
	await mode_key(KEY_E, 0, true)
	view._process(1.0)
	await mode_key(KEY_E, 0, false, false)
	check(panel.authoring.find_entity(&"height_1").cell.y == 4 and panel.authoring._history.size() == history_size + 1, "Holding E, repeats and release add no movement or history")
	check(view.camera.position == camera_origin and view.layer == paint_height and not view.is_navigating(), "Selection QE leaves the camera and paint height unchanged")
	check(panel.authoring.undo() and panel.authoring.find_entity(&"height_1").cell.y == 3, "One undo restores a keyboard height move")
	check(panel.authoring.redo() and panel.authoring.find_entity(&"height_1").cell.y == 4, "Redo reapplies a keyboard height move")
	await mode_key(KEY_Q)
	await mode_key(KEY_Q, 0, false, false)
	check(panel.authoring.find_entity(&"height_1").cell.y == 3, "Q lowers a single selection by one cell")
	panel._select(&"height_0", true)
	history_size = panel.authoring._history.size()
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	check(panel.authoring.find_entity(&"height_0").cell.y == 3 and panel.authoring.find_entity(&"height_1").cell.y == 4, "E moves a stacked selection together, allowing its vacated cells")
	check(panel.authoring._history.size() == history_size + 1, "Group height movement records one undo action")
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	check(panel.authoring.find_entity(&"height_0").cell.y == 3 and panel.authoring.find_entity(&"height_1").cell.y == 4 and panel.authoring._history.size() == history_size + 1, "One blocked member rejects the whole height move without history")
	check(not panel.authoring.last_error.is_empty(), "Blocked height movement reports the validation error")
	check(panel.authoring.undo() and panel.authoring.find_entity(&"height_0").cell.y == 2 and panel.authoring.find_entity(&"height_1").cell.y == 3, "One undo restores the entire group's relative heights")
	for id in [&"height_0", &"height_1"]:
		var entity = panel.authoring.find_entity(id)
		check(entity.quarter_turns == 1 and entity.mirrored and entity.overrides == {"weight": 7}, "QE preserves orientation and overrides")
	history_size = panel.authoring._history.size()
	for modifiers in [KEY_MASK_CTRL, KEY_MASK_ALT, KEY_MASK_SHIFT, KEY_MASK_META]:
		# Exercise the viewport guard without invoking Godot's global Ctrl+Q quit command.
		var modified = InputEventKey.new()
		modified.physical_keycode = KEY_Q
		modified.pressed = true
		modified.ctrl_pressed = bool(modifiers & KEY_MASK_CTRL)
		modified.alt_pressed = bool(modifiers & KEY_MASK_ALT)
		modified.shift_pressed = bool(modifiers & KEY_MASK_SHIFT)
		modified.meta_pressed = bool(modifiers & KEY_MASK_META)
		view._input(modified)
	focus_control(panel, panel._settings_title)
	await mode_key(KEY_Q)
	await mode_key(KEY_Q, 0, false, false)
	panel._select(&"height_1")
	panel._coords[1].get_line_edit().grab_focus()
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	check(panel.authoring._history.size() == history_size and panel.authoring.find_entity(&"height_1").cell.y == 3, "Modified QE and text or coordinate editing do not move selection")
	panel._confirm.popup_centered()
	await get_tree().process_frame
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	panel._confirm.hide()
	view.grab_focus()
	check(panel.authoring._history.size() == history_size, "Modal dialogs block selection QE")
	await mode_key(KEY_W)
	await mode_key(KEY_D)
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	check(panel.authoring.find_entity(&"height_1").cell.y == 4 and view._navigation_keys.has(KEY_W) and view._navigation_keys.has(KEY_D), "Raising selection preserves every held flight key")
	await mode_key(KEY_W, 0, true)
	camera_origin = view.camera.position
	view._process(0.25)
	var direction = (view.camera.basis.x - view.camera.basis.z).normalized()
	check(view.camera.position.is_equal_approx(camera_origin + direction * view._fly_speed * 0.25), "Camera flight continues after E without repressing WASD")
	await mode_key(KEY_W, 0, false, false)
	await mode_key(KEY_Q)
	await mode_key(KEY_Q, 0, false, false)
	camera_origin = view.camera.position
	view._process(0.25)
	check(panel.authoring.find_entity(&"height_1").cell.y == 3 and view.camera.position.is_equal_approx(camera_origin + view.camera.basis.x * view._fly_speed * 0.25), "Lowering selection preserves the remaining flight key after another is released")
	await mode_key(KEY_D, 0, false, false)
	camera_origin = view.camera.position
	view._process(0.25)
	check(not view.is_navigating() and view.camera.position == camera_origin, "Releasing the last flight key still stops immediately after QE")
	history_size = panel.authoring._history.size()
	var right = InputEventMouseButton.new()
	right.button_index = MOUSE_BUTTON_RIGHT
	right.pressed = true
	right.position = view.size / 2
	view.gui_input.emit(right)
	camera_origin = view.camera.position
	await mode_key(KEY_E)
	view._process(0.25)
	await mode_key(KEY_E, 0, false, false)
	check(view.camera.position.is_equal_approx(camera_origin + Vector3.UP * view._fly_speed * 0.25) and panel.authoring._history.size() == history_size, "Right+E flies the camera even with a selection")
	view._stop_navigation()
	panel._select(&"")
	camera_origin = view.camera.position
	await mode_key(KEY_Q)
	view._process(0.25)
	await mode_key(KEY_Q, 0, false, false)
	check(view.camera.position.is_equal_approx(camera_origin + Vector3.DOWN * view._fly_speed * 0.25), "QE without a selection retains camera flight")
	view.set_process(true)
	panel._open(previous)

func check_paint_height_offset(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	for index in range(2):
		var entity = GGEntityPlacement.new()
		entity.entity_id = StringName("paint_height_%d" % index)
		entity.definition = fixture.palette[3]
		entity.cell = Vector3i(index * 3, 4 + index * 2, 0)
		fixture.entities.append(entity)
	panel._open(fixture)
	panel._set_mode(2)
	panel._select(&"paint_height_0")
	panel._set_mode(0)
	panel._choose_definition(3)
	var view = panel.viewport
	view._yaw = 0
	view._pitch = deg_to_rad(75.2)
	view.frame_level()
	view.set_process(false)
	view.grab_focus()
	var point = view.camera.unproject_position(Vector3(0, 4.48, 0)).round()
	if not await pointer_motion(view, point): return
	var base: Vector3i = view.input_cell_at(point)
	var camera_origin = view.camera.position
	var height = view.layer
	var history = panel.authoring._history.size()
	await mode_key(KEY_E)
	check(panel.stroke.height_offset() == 1 and view._ghost != null and view._ghost.position == Vector3(base + Vector3i.UP), "Paint E immediately raises the stationary-pointer ghost by one world-Y cell")
	check(panel._hint.text.contains("offset +1") and panel._pointer_status.text.contains("Offset +1"), "Paint offset stays visible in the tool hint and coordinates")
	await mode_key(KEY_E, 0, true)
	await mode_key(KEY_E, 0, false, false)
	view._process(0.25)
	check(panel.stroke.height_offset() == 1 and view.camera.position == camera_origin and view.layer == height and panel.authoring._history.size() == history, "Paint QE ignores repeats and release, preserves camera/Height and creates no history")
	check(panel.authoring.find_entity(&"paint_height_0").cell == Vector3i(0, 4, 0), "Paint QE leaves retained selected entities in place")
	var upper_point = view.camera.unproject_position(Vector3(3, 6.48, 0)).round()
	if not await pointer_motion(view, upper_point): return
	check(view._ghost.position == Vector3(3, 8, 0), "Moving the pointer to a higher surface keeps the same offset")
	if not await pointer_motion(view, point): return
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
	await mode_key(KEY_Q)
	await mode_key(KEY_Q, 0, false, false)
	check(panel.stroke.height_offset() == 1, "QE cannot alter an in-progress paint stroke")
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
	check(fixture.entities.size() == 3 and fixture.entities.back().cell == base + Vector3i.UP, "Click commits the exact offset preview")
	check(panel.authoring.undo() and fixture.entities.size() == 2, "Offset paint is undoable")
	check(panel.authoring.redo() and fixture.entities.back().cell == base + Vector3i.UP, "Offset paint redo retains exact coordinates")
	panel.authoring.undo()
	view.grab_focus()
	if not await pointer_motion(view, point): return
	await mode_key(KEY_Q)
	await mode_key(KEY_Q, 0, false, false)
	await mode_key(KEY_Q)
	await mode_key(KEY_Q, 0, false, false)
	check(view._ghost != null and view._ghost.position == Vector3(base + Vector3i.DOWN) and ghost_has_color(view._ghost, Color(1.0, 0.2, 0.2, 0.6)), "Solid overlap retains a red preview at the requested lower height")
	check(panel._pointer_status.text.contains("Invalid") and panel._pointer_status.tooltip_text.contains("overlap"), "Invalid paint coordinates explain the collision")
	history = panel.authoring._history.size()
	var future = panel.authoring._future.size()
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
	check(fixture.entities.size() == 2 and panel.authoring._history.size() == history and panel.authoring._future.size() == future, "Invalid clicking never lifts the entity or adds/discards history")
	for modifiers in [KEY_MASK_CTRL, KEY_MASK_ALT, KEY_MASK_SHIFT, KEY_MASK_META]:
		var modified = InputEventKey.new()
		modified.physical_keycode = KEY_Q
		modified.pressed = true
		modified.ctrl_pressed = bool(modifiers & KEY_MASK_CTRL)
		modified.alt_pressed = bool(modifiers & KEY_MASK_ALT)
		modified.shift_pressed = bool(modifiers & KEY_MASK_SHIFT)
		modified.meta_pressed = bool(modifiers & KEY_MASK_META)
		view._input(modified)
	focus_control(panel, panel._settings_title)
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	panel._height.get_line_edit().grab_focus()
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	panel._confirm.popup_centered()
	await get_tree().process_frame
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	panel._confirm.hide()
	view.grab_focus()
	check(panel.stroke.height_offset() == -1, "Modifiers, text fields, height editing and modal dialogs do not change Paint offset")
	var brush = panel._definition
	camera_mouse(view, MOUSE_BUTTON_RIGHT, true, point)
	camera_origin = view.camera.position
	await mode_key(KEY_E)
	view._process(0.25)
	await mode_key(KEY_E, 0, false, false)
	camera_mouse(view, MOUSE_BUTTON_RIGHT, false, point)
	check(view.camera.position.is_equal_approx(camera_origin + Vector3.UP * view._fly_speed * 0.25) and panel.stroke.height_offset() == -1 and panel._definition == brush, "Right+E flies in Paint without adjusting offset or picking a brush")
	panel._set_mode(2)
	check(panel.stroke.height_offset() == 0, "Leaving Paint clears the offset")
	panel._set_mode(0)
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	panel._choose_definition(4)
	check(panel.stroke.height_offset() == 0, "Choosing another brush clears the offset")
	await mode_key(KEY_E)
	await mode_key(KEY_E, 0, false, false)
	panel._open(fixture)
	check(panel.stroke.height_offset() == 0, "Opening a level clears the offset")
	view.set_process(true)
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	panel._set_mode(0)

func check_auto_lift_height_offset(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var view = panel.viewport
	for binding in [[KEY_E, 3], [KEY_Q, 1]]:
		var fixture = GGLevel.new()
		fixture.palette = GGDefaults.palette()
		for index in range(2):
			var entity = GGEntityPlacement.new()
			entity.entity_id = StringName("auto_lift_%d" % index)
			entity.definition = fixture.palette[3]
			entity.cell = Vector3i(index, index, 0)
			fixture.entities.append(entity)
		var shaped = fixture.palette[3].duplicate(true) as GGEntityDefinition
		shaped.definition_id = &"auto_lift_brush"
		shaped.shape.assign([Vector3i.ZERO, Vector3i.RIGHT])
		fixture.palette.append(shaped)
		panel._open(fixture)
		panel.authoring.paint(fixture.palette[3], Vector3i(10, 0, 0))
		panel.authoring.undo()
		panel._set_mode(0)
		panel._choose_definition(fixture.palette.size() - 1)
		panel._turns.value = 0
		panel._mirror.button_pressed = false
		view.set_layer(0)
		view._yaw = 0
		view._pitch = deg_to_rad(75.2)
		view.frame_level()
		view.set_process(false)
		view.grab_focus()
		var point = view.camera.unproject_position(Vector3(0, 0.48, 0)).round()
		if not await pointer_motion(view, point): return
		check(view._ghost != null and view._ghost.position == Vector3(0, 2, 0), "Complete brush auto-lifts the actual editor preview above a neighbouring solid")
		var history = panel.authoring._history.size()
		var future = panel.authoring._future.size()
		panel.authoring.dirty = false
		await mode_key(binding[0])
		await mode_key(binding[0], 0, false, false)
		var target = Vector3i(0, binding[1], 0)
		check(view._ghost != null and view._ghost.position == Vector3(target), "First QE moves the stationary-pointer editor preview one cell from its auto-lifted height")
		check(ghost_has_color(view._ghost, Color(0.5, 1.0, 0.8, 0.45) if binding[0] == KEY_E else Color(1.0, 0.2, 0.2, 0.6)), "Full-shape validation colors the raised preview valid and the lowered preview red")
		check(not panel.authoring.dirty and panel.authoring._history.size() == history and panel.authoring._future.size() == future, "First QE after auto-lifting changes no authored data or history")
		camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
		camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
		if binding[0] == KEY_E:
			check(fixture.entities.size() == 3 and fixture.entities.back().cell == target and fixture.validate().is_empty(), "Click places the complete brush exactly at the raised editor preview")
			check(panel.authoring.undo() and fixture.entities.size() == 2, "Raised auto-lift transition is one undoable editor stroke")
		else:
			check(fixture.entities.size() == 2 and not panel.authoring.dirty and panel.authoring._history.size() == history and panel.authoring._future.size() == future, "Invalid first Q click preserves the level and undo/redo history")
	view.set_process(true)
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	panel._set_mode(0)

func ghost_has_color(node: Node, color: Color) -> bool:
	if node is MeshInstance3D and not node.material_override.albedo_color.is_equal_approx(color): return false
	for child in node.get_children():
		if not ghost_has_color(child, color): return false
	return true

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
	check(panel.selection.ids() == [&"member_0", &"member_1"], "Shift-click adds an entity to the selection")
	check(view._move_gizmo.position == Vector3(3, 2, 0), "Gizmo follows the last selected entity")
	selection_click(view, fixture.entities[1].cell, true)
	check(panel.selection.ids() == [&"member_0"], "Shift-click removes a selected entity")
	check(view._move_gizmo.position == Vector3(0, 2, 0), "Removing the active entity restores the preceding selection anchor")
	selection_click(view, Vector3i(-3, 2, 0), true)
	check(panel.selection.ids() == [&"member_0"], "Shift-click on empty space preserves selection")
	selection_click(view, fixture.entities[2].cell)
	check(panel.selection.ids() == [&"member_2"], "Plain click replaces selection")
	selection_click(view, Vector3i(-3, 2, 0))
	check(panel.selection.ids() == [], "Plain click on empty space clears selection")
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
	check(not panel.selection.is_valid(), "One blocked member invalidates the group preview")
	check(surface_feedback_is(view, GGEditorEntitySurfaces.RED, false), "Every selected surface becomes steady red on collision")
	gizmo_release(panel, grabbed + Vector3(3, 0, 0))
	check(fixture.entities[0].cell == Vector3i(0, 2, 0) and fixture.entities[1].cell == Vector3i(3, 2, 0), "Invalid release restores the entire group")
	grabbed = gizmo_press(panel, 0)
	gizmo_motion(panel, grabbed + Vector3.RIGHT)
	await mode_key(KEY_ESCAPE)
	check(view.board.roots[&"member_0"].position == Vector3(0, 2, 0) and view.board.roots[&"member_1"].position == Vector3(3, 2, 0), "Esc restores every member's visual position")
	panel._select(&"member_0")
	focus_control(panel, panel._settings_title)
	await mode_key(KEY_DELETE)
	focus_control(panel, panel._coords[0].get_line_edit())
	check(panel._coords[0].editable and panel._coords[0].get_line_edit().has_focus(), "Delete protection is tested with an editable coordinate input focused")
	await mode_key(KEY_DELETE)
	check(fixture.entities.size() == 3, "Delete in text and property inputs preserves selected entities")
	panel._select(&"member_1", true)
	view.grab_focus()
	for modifiers in [KEY_MASK_CTRL, KEY_MASK_ALT, KEY_MASK_SHIFT, KEY_MASK_META]:
		await mode_key(KEY_DELETE, modifiers)
	await mode_key(KEY_DELETE, 0, true)
	await mode_key(KEY_DELETE, 0, false, false)
	check(fixture.entities.size() == 3, "Modified Delete, repeat and release preserve selected entities")
	panel._set_mode(0)
	await mode_key(KEY_DELETE)
	check(fixture.entities.size() == 3, "Delete outside Select mode preserves entities")
	panel._set_mode(2)
	panel._confirm.popup_centered()
	await get_tree().process_frame
	await mode_key(KEY_DELETE)
	check(fixture.entities.size() == 3, "Modal dialogs block Delete")
	panel._confirm.hide()
	view.grab_focus()
	panel._select(&"member_0")
	await mode_key(KEY_DELETE)
	check(fixture.entities.size() == 2 and panel.authoring.find_entity(&"member_0") == null and panel.selection.ids().is_empty(), "Delete removes a single selected entity and clears selection")
	var history_size = panel.authoring._history.size()
	await mode_key(KEY_DELETE)
	check(panel.authoring._history.size() == history_size, "Delete with no selection adds no history")
	check(panel.authoring.undo() and fixture.entities.size() == 3, "One undo restores a keyboard-deleted entity")
	panel._select(&"member_0")
	panel._select(&"member_1", true)
	panel._duplicate()
	check(fixture.entities.size() == 5 and panel.selection.ids().size() == 2 and not panel.selection.ids().has(&"member_0") and not panel.selection.ids().has(&"member_1"), "Duplicate selects the new group")
	var copies = panel.selection.ids().duplicate()
	await mode_key(KEY_DELETE)
	check(fixture.entities.size() == 3 and panel.selection.ids().is_empty(), "Delete removes the entire group and clears selection")
	check(panel.authoring.undo() and fixture.entities.size() == 5 and panel.selection.ids().is_empty(), "Undo restores deleted entities without changing selection")
	check(panel.authoring.undo() and fixture.entities.size() == 3, "A second undo removes the duplicate group")
	check(panel.authoring.redo() and panel.authoring.find_entity(copies[0]) != null, "Redo restores copies with stable IDs")
	selection_click(view, fixture.entities[0].cell)
	check(panel._coords[0].editable and not panel._apply_button.disabled and panel._inspector.get_edited_object() != null, "Returning to one selection restores single-entity editing")
	panel._shape_mode.button_pressed = true
	check(panel.selection.ids().is_empty() and not view._move_gizmo.visible, "Entering shape editing clears selection")
	panel._shape_mode.button_pressed = false
	view._pitch = 0.0
	view._pivot = Vector3(3, 2, 0)
	view._camera_position()
	await get_tree().process_frame
	selection_click(view, fixture.entities[0].cell, true)
	selection_click(view, fixture.entities[1].cell, true)
	check(panel.selection.ids() == [&"member_0", &"member_1"], "Visible entities can be selected when the view ray cannot reach the placement plane")
	panel._open(previous)
	check(panel.selection.ids().is_empty(), "Opening another level clears selection")
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
	panel.selection.begin_move()
	panel.selection.preview_move(Vector3i(marker.cell.x, fixture.void_height, marker.cell.z))
	check(surface_feedback_is(view, GGEditorEntitySurfaces.RED, false), "Invalid preview uses steady red surfaces")
	panel.selection.finish_move(false)
	check(surface_feedback_is(view, GGEditorEntitySurfaces.BLUE, true), "Returning to a valid preview restores blue breathing")
	check(root.get_child(0).material_override == authored_material, "Surface feedback preserves original entity materials")
	panel._set_mode(1)
	view._update_erase_hover(rim)
	check(view._erase_target == marker.entity_id and surface_feedback_is(view, GGEditorEntitySurfaces.RED, true), "Erase hover breathes red on precisely the entity under the pointer")
	check(panel.selection.ids() == [marker.entity_id], "Erase mode preserves the recorded selection")
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

func check_paint_surfaces(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	panel._open(fixture)
	panel._choose_definition(3)
	panel._set_mode(0)
	panel.authoring.paint(panel._definition, Vector3i(0, 4, 0))
	var view = panel.viewport
	view.set_layer(0)
	view.camera.position = Vector3(7, 10, 12)
	view.camera.look_at(Vector3(0, 4, 0))
	var point = view.camera.unproject_position(Vector3(0, 4.48, 0))
	var motion = InputEventMouseMotion.new()
	motion.position = point
	view.gui_input.emit(motion)
	check(view._ghost != null and view._ghost.position == Vector3(0, 5, 0), "Paint preview snaps to the pointed elevated top instead of the distant height plane")
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
	check(fixture.entities.back().cell == Vector3i(0, 5, 0), "Paint stacks directly on the pointed elevated entity")
	check(panel.authoring.undo() and fixture.entities.size() == 1, "Surface paint is one undo action")
	check(panel.authoring.redo() and fixture.entities.back().cell == Vector3i(0, 5, 0), "Redo restores the snapped placement")
	panel.authoring.undo()
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = point + Vector2(0.1, 0.1)
	view.gui_input.emit(motion)
	check(fixture.entities.size() == 2, "A small pointer motion cannot stack onto an entity created by the same stroke")
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
	panel.authoring.undo()
	view.camera.position = Vector3(0, 4, 10)
	view.camera.look_at(Vector3(0, 4, 0))
	point = view.camera.unproject_position(Vector3(0, 4, 0.5))
	motion.button_mask = 0
	motion.position = point
	view.gui_input.emit(motion)
	check(view.cell_at(point) == null, "Horizontal surface test cannot reach the Height plane")
	check(view._ghost.position == Vector3(0, 4, 1), "Paint preview snaps onto a vertical grid face")
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
	check(fixture.entities.back().cell == Vector3i(0, 4, 1), "Paint clicks work on surfaces without a Height plane intersection")
	panel.authoring.undo()
	var shaped = panel._definition.duplicate(true) as GGEntityDefinition
	shaped.shape.assign([Vector3i.DOWN, Vector3i.ZERO])
	fixture.palette.append(shaped)
	panel._refresh()
	panel._choose_definition(fixture.palette.size() - 1)
	view.camera.position = Vector3(7, 10, 12)
	view.camera.look_at(Vector3(0, 4, 0))
	point = view.camera.unproject_position(Vector3(0, 4.48, 0))
	motion.position = point
	view.gui_input.emit(motion)
	check(view._ghost.position == Vector3(0, 6, 0), "Surface placement aligns the lowest occupied cell of the complete brush")
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
	check(fixture.entities.back().cell == Vector3i(0, 6, 0), "Multi-cell surface preview agrees with committed paint")

	fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	var bread = load("res://examples/entities/quack_bread.tres") as GGEntityDefinition
	fixture.palette.append(bread)
	panel._open(fixture)
	panel._choose_definition(fixture.palette.size() - 1)
	panel._set_mode(0)
	panel.authoring.paint(fixture.palette[0], Vector3i(0, 3, 0))
	panel.authoring.paint(bread, Vector3i(0, 4, 0))
	view.set_layer(0)
	view.camera.position = Vector3(7, 10, 12)
	view.camera.look_at(Vector3(0, 4, 0))
	point = view.camera.unproject_position(Vector3(0, 4.48, 0))
	motion.position = point
	view.gui_input.emit(motion)
	check(view._ghost.position == Vector3(0, 5, 0), "Bread preview snaps above non-solid bread instead of the ground beneath it")
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	motion.position = point + Vector2(0.1, 0.1)
	view.gui_input.emit(motion)
	check(fixture.entities.size() == 3 and fixture.entities.back().cell == Vector3i(0, 5, 0), "Click stacks bread and dragging cannot add more layers in the same stroke")
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
	point = view.camera.unproject_position(Vector3(0, 5.48, 0))
	motion.button_mask = 0
	motion.position = point
	view.gui_input.emit(motion)
	check(view._ghost.position == Vector3(0, 6, 0), "A later bread stroke previews the next layer")
	camera_mouse(view, MOUSE_BUTTON_LEFT, true, point)
	camera_mouse(view, MOUSE_BUTTON_LEFT, false, point)
	check(fixture.entities.size() == 4 and fixture.entities.back().cell == Vector3i(0, 6, 0), "A second click stacks another bread layer")
	check(panel.authoring.undo() and fixture.entities.size() == 3, "Undo removes one bread stroke")
	check(panel.authoring.redo() and fixture.entities.back().cell == Vector3i(0, 6, 0), "Redo restores the bread layer")

	view._yaw = 0.0
	view._pitch = deg_to_rad(75.2)
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	view.frame_level()

# Establish the window pointer through Input, then route the stationary
# shortcuts and clicks synchronously through that Window's real GUI handlers.
# Never yield within a stationary gesture:
# native motion may replace this position at the next process frame.
func pointer_key(view: GGEditorViewport, code: Key) -> void:
	var event = InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	view.get_window().push_input(event, true)
	event = event.duplicate()
	event.pressed = false
	view.get_window().push_input(event, true)

func pointer_button(view: GGEditorViewport, point: Vector2, pressed: bool) -> bool:
	var event = InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.position = view.get_global_transform_with_canvas() * point
	event.global_position = event.position
	var received = [false]
	var observe = func(input: InputEvent):
		if input is InputEventMouseButton and input.button_index == MOUSE_BUTTON_LEFT and input.pressed == pressed and input.position.distance_to(point) < 1.5:
			received[0] = true
	view.gui_input.connect(observe)
	view.get_window().push_input(event, true)
	view.gui_input.disconnect(observe)
	check(received[0], "INPUT_SETUP: first click did not reach the canvas; pressed=%s requested=%s actual=%s" % [pressed, point, view.get_local_mouse_position()])
	return received[0]

func pointer_valid(view: GGEditorViewport, point: Vector2, stage: String) -> bool:
	var native = DisplayServer.get_name() != "headless"
	var valid = view.get_local_mouse_position().distance_to(point) < 1.5
	valid = valid and (not native or view.get_window().has_focus())
	check(valid, "INPUT_SETUP: %s aborted; requested=%s actual=%s backend=%s focus=%s window=%s screen=%s canvas=%s" % [stage, point, view.get_local_mouse_position(), DisplayServer.get_name(), view.get_window().has_focus(), view.get_window().position, view.get_window().current_screen, view.get_global_transform_with_canvas()])
	return valid

func warp_pointer(view: GGEditorViewport, point: Vector2) -> void:
	var helper = OS.get_environment("GGG_POINTER_HELPER")
	if OS.get_name() == "Windows" and not helper.is_empty():
		# The native bridge converts client pixels with ClientToScreen, so
		# negative monitor origins do not depend on Godot screen transforms.
		var window_point = view.get_global_transform_with_canvas() * point
		OS.execute(OS.get_environment("GGG_POINTER_PYTHON"), [helper, "--warp-cursor", str(roundi(window_point.x)), str(roundi(window_point.y))])
	else:
		view.warp_mouse(point)

func pointer_motion(view: GGEditorViewport, point: Vector2) -> bool:
	# Settle deferred layout before converting canvas coordinates.
	for frame in range(3): await get_tree().process_frame
	if DisplayServer.get_name() != "headless":
		# Graphical backends poll the OS cursor. Require three stable samples before
		# starting the synthetic gesture. It needs exclusive desktop input.
		view.get_window().grab_focus()
		warp_pointer(view, point)
		var stable = 0
		for attempt in range(20):
			await get_tree().create_timer(0.05).timeout
			if view.get_local_mouse_position().distance_to(point) < 1.5 and view.get_window().has_focus():
				stable += 1
				if stable == 3: break
			else:
				stable = 0
				warp_pointer(view, point)
		if stable < 3:
			check(false, "INPUT_SETUP: native pointer did not settle; requested=%s actual=%s backend=%s focus=%s window=%s screen=%s" % [point, view.get_local_mouse_position(), DisplayServer.get_name(), view.get_window().has_focus(), view.get_window().position, view.get_window().current_screen])
			return false
	var motion = InputEventMouseMotion.new()
	motion.position = view.get_global_transform_with_canvas() * point
	motion.global_position = motion.position
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	view.get_window().push_input(motion.duplicate(), true)
	if DisplayServer.get_name() != "headless": await get_tree().process_frame
	return pointer_valid(view, point, "pointer motion")

func check_paint_mode_preview(panel: GGEditorPanel) -> void:
	var previous = panel.authoring.level
	var definition = panel._definition
	var fixture = GGLevel.new()
	fixture.palette = GGDefaults.palette()
	var surface = GGEntityPlacement.new()
	surface.entity_id = &"mode_surface"
	surface.definition = fixture.palette[3]
	fixture.entities.append(surface)
	var shaped = fixture.palette[3].duplicate(true) as GGEntityDefinition
	shaped.shape.assign([Vector3i.ZERO, Vector3i(0, -1, 1)])
	fixture.palette.append(shaped)
	panel._open(fixture)
	var view = panel.viewport
	view.grab_focus()
	view.set_layer(0)
	# Both previous tools, elevated surfaces, and a rotated/mirrored brush.
	for scenario in [[1, 0, false], [2, 4, false], [1, 4, true], [2, 4, true]]:
		surface = fixture.entities[0]
		surface.cell = Vector3i(0, scenario[1], 0)
		panel._refresh()
		panel._choose_definition(fixture.palette.size() - 1 if scenario[2] else 3)
		panel._turns.value = 1 if scenario[2] else 0
		panel._mirror.button_pressed = scenario[2]
		view.camera.position = Vector3(7, surface.cell.y + 6, 12)
		view.camera.look_at(Vector3(surface.cell))
		for frame in range(2): await get_tree().process_frame
		pointer_key(view, KEY_2 if scenario[0] == 1 else KEY_3)
		var point = view.camera.unproject_position(Vector3(surface.cell) + Vector3(0, 0.48, 0)).round()
		if not await pointer_motion(view, point): continue
		check(panel._mode == scenario[0], "Previous tool receives the pointer before switching to Paint")
		check(view.entity_at(point) == surface.entity_id, "Select/Erase still pick the visible model")
		pointer_key(view, KEY_1)
		if not pointer_valid(view, point, "Paint shortcut"): continue
		var expected = Vector3i(0, surface.cell.y + (2 if scenario[2] else 1), 0)
		check(view._ghost != null and view._ghost.visible and view._ghost.position == Vector3(expected), "Switching to Paint recomputes the fitted ghost without moving the mouse")
		# No motion between the shortcut and the click.
		if not pointer_valid(view, point, "first Paint click"): continue
		var pressed = pointer_button(view, point, true)
		var released = pointer_button(view, point, false)
		if not pressed or not released:
			panel.stroke.finish()
			if fixture.entities.size() > 1: panel.authoring.undo()
			continue
		check(fixture.entities.size() == 2 and fixture.entities.back().cell == expected, "The first stationary Paint click agrees with the tool-switch preview")
		check(panel.authoring.undo() and fixture.entities.size() == 1, "Tool-switch paint remains one undo action")
	await check_paint_miss(panel, fixture)
	await check_paint_outside(panel, surface.cell)
	panel._turns.value = 0
	panel._mirror.button_pressed = false
	view._yaw = 0.0
	view._pitch = deg_to_rad(75.2)
	panel._open(previous)
	panel._choose_definition(previous.palette.find(definition))
	panel._set_mode(0)
	view.frame_level()

func check_paint_miss(panel: GGEditorPanel, fixture: GGLevel) -> void:
	var view = panel.viewport
	view.camera.position = Vector3(0, 8, 12)
	view.camera.look_at(Vector3(0, 8, 0))
	pointer_key(view, KEY_2)
	var point = (view.size * 0.5).floor()
	if not await pointer_motion(view, point): return
	check(view.input_cell_at(point) == null and view.entity_at(point) == &"", "Horizontal miss has neither a plane nor a surface target")
	pointer_key(view, KEY_1)
	if not pointer_valid(view, point, "miss shortcut"): return
	check(not view._ghost or not view._ghost.visible, "Switching to Paint hides a stale ghost when the ray misses")
	if not pointer_valid(view, point, "miss click"): return
	var pressed = pointer_button(view, point, true)
	var released = pointer_button(view, point, false)
	if not pressed or not released:
		panel.stroke.finish()
		return
	check(fixture.entities.size() == 1 and not panel.stroke.is_active(), "Clicking a missed Paint target neither places nor leaves a stroke active")

func check_paint_outside(panel: GGEditorPanel, surface_cell: Vector3i) -> void:
	var view = panel.viewport
	view.camera.position = Vector3(7, 10, 12)
	view.camera.look_at(Vector3(surface_cell))
	if not await pointer_motion(view, view.size * 0.5): return
	pointer_key(view, KEY_2)
	var point = Vector2(-10, -10)
	if not await pointer_motion(view, point): return
	pointer_key(view, KEY_1)
	if not pointer_valid(view, point, "outside shortcut"): return
	check(not view._ghost or not view._ghost.visible, "Switching to Paint outside the canvas keeps the ghost hidden")
