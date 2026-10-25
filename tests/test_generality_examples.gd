extends SceneTree
var checks = 0
var failures = 0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	_test_rolling()
	_test_gravity()
	_test_links()
	await _test_custom_runtime()
	print("Generality examples: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _test_rolling() -> void:
	var level = load("res://examples/levels/rolling.tres")
	check(level is GGLevel, "The rolling block example is an authored native level")
	if not level is GGLevel: return
	var session = GGSession.new()
	check(session.start(level).is_empty(), "Rolling level loads through the shared session")
	var initial = session.snapshot()
	check(session.move(&"block", Vector3i.RIGHT), "The marked block rolls around its contact edge")
	check(GGGrid.cells(session.entities[&"block"]).has(Vector3i(2, 0, 1)), "Rolling changes orientation and occupied cells together")
	check(session.move(&"block", Vector3i.RIGHT) and session.status == &"won", "The block reaches the goal standing on the specified face")
	check(session.undo() and session.status == &"playing", "Undo restores the previous complete rolling pose")
	check(session.undo() and session.snapshot() == initial, "Two undos restore the authored pose")
	check(session.redo() and session.redo() and session.status == &"won", "Redo restores rolling completion without rerunning rules")

func _test_gravity() -> void:
	var level = load("res://examples/levels/gravity.tres")
	check(level is GGLevel, "The changing-gravity example is an authored level")
	if not level is GGLevel: return
	var session = GGSession.new()
	check(session.start(level).is_empty(), "Changing-gravity level loads")
	for direction in [Vector3i.RIGHT, Vector3i.UP, Vector3i.LEFT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.DOWN, Vector3i.ZERO]:
		var before = session.snapshot()
		check(session.act(&"gravity", {"direction": direction}), "A gravity switch accepts an axis or off")
		check(session.mechanic_state.gravity_direction == direction, "The selected gravity is gameplay state")
		var after = session.snapshot()
		check(session.undo() and session.snapshot() == before, "Undo restores gravity and every moved entity")
		check(session.redo() and session.snapshot() == after, "Redo restores the resolved gravity action")
	var before = session.snapshot()
	check(not session.act(&"gravity", {"direction": Vector3i(1, 1, 0)}) and session.snapshot() == before, "Non-axis gravity is rejected atomically")

func _test_links() -> void:
	var level = load("res://examples/levels/links.tres")
	check(level is GGLevel, "The linked-mechanism example is an authored level")
	if not level is GGLevel: return
	var session = GGSession.new()
	check(session.start(level).is_empty(), "Linked mechanisms load through the shared session")
	check(session.move(&"actor", Vector3i.RIGHT), "Actor steps onto a pressure switch")
	check(session.entities[&"door_a"].state.open and session.entities[&"door_b"].state.open, "One switch opens both referenced doors")
	check(session.move(&"actor", Vector3i.RIGHT) and not session.entities[&"door_a"].state.open, "Leaving the pressure switch closes the doors")
	check(session.undo() and session.entities[&"door_a"].state.open, "Undo restores pressure and linked door states")
	session.restart()
	for direction in [Vector3i.BACK, Vector3i.BACK, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.RIGHT, Vector3i.RIGHT]:
		check(session.move(&"actor", direction), "The crate can hold the switch while the actor crosses a door")
	var before_portal = session.snapshot()
	check(session.move(&"actor", Vector3i.RIGHT), "Actor enters the directed portal")
	check(session.entities[&"actor"].cell == Vector3i(7, 0, 2), "The portal resolves the selected destination entity")
	var after_portal = session.snapshot()
	check(session.undo() and session.snapshot() == before_portal, "Portal movement and mechanism state undo together")
	check(session.redo() and session.snapshot() == after_portal, "Portal redo restores the resolved result")
	check(session.move(&"actor", Vector3i.FORWARD) and session.status == &"won", "The linked-mechanism example is playable to completion")

func _test_custom_runtime() -> void:
	var level: GGLevel = ResourceLoader.load("res://examples/levels/gravity.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	level.title = "Unsaved gravity layout"
	var editor = GGLevelAuthoring.new()
	editor.open(level)
	var path = editor.prepare_playtest("user://custom_gravity_runtime")
	check(not path.is_empty(), "Custom runtime preparation accepts unsaved configuration")
	if path.is_empty(): return
	var entry = load(path).instantiate()
	root.add_child(entry)
	await process_frame
	var game = entry.get_child(0)
	check(game.get_script().resource_path == "res://examples/runtime/gravity_game.gd", "Playtest launches the game-supplied runtime scene")
	check(game.level.title == "Unsaved gravity layout" and game.level != level, "The custom runtime receives the isolated unsaved level")
	var event = InputEventKey.new()
	event.pressed = true
	event.physical_keycode = KEY_4
	game._unhandled_key_input(event)
	check(game.session.mechanic_state.gravity_direction == Vector3i.RIGHT, "Custom runtime input dispatches through shared action history")
	check(game.session.entities[&"actor"].cell.x == 2, "The runtime gravity command settles against the right boundary")
	check(level.entities[-2].cell == Vector3i(1, 1, 1), "Runtime gravity leaves the original authored layout unchanged")
	for frame in 120:
		if not game._busy: break
		await create_timer(0.01).timeout
	entry.queue_free()
	await process_frame
