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
	EditorInterface.set_main_screen_editor("Grid Levels")
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
		var image = EditorInterface.get_base_control().get_viewport().get_texture().get_image()
		image.save_png(OS.get_environment("GGG_EDITOR_SCREENSHOT"))
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
