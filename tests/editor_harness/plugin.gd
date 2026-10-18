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
