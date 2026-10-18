extends SceneTree
var failures = 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var authored: GGLevel = load("res://examples/levels/sokoban.tres")
	var player_cell = authored.entities[73].cell
	var game = load("res://examples/sokoban.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game._view.roots.size() == authored.entities.size(), "Runtime renders every authored entity")
	check(game.session.status == &"playing", "Runtime starts in the playing state")
	var event = InputEventKey.new()
	event.physical_keycode = KEY_W
	event.pressed = true
	game._unhandled_key_input(event)
	await create_timer(0.4).timeout
	check(game.session.entities[game.session.player_id()].cell == Vector3i(2, 0, 3), "Keyboard input runs and animates a grid move")
	check(not game._busy, "Animation releases input after completing")
	game._history_action("Undo")
	await create_timer(0.3).timeout
	check(game.session.entities[game.session.player_id()].cell == Vector3i(2, 0, 4), "Runtime undo control restores the player")
	check(authored.entities[73].cell == player_cell, "Running a scene leaves the authored resource unchanged")
	game.queue_free()
	await process_frame
	var pipes = load("res://examples/pipes.tscn").instantiate()
	root.add_child(pipes)
	await process_frame
	check(pipes._view.roots.size() == pipes.level.entities.size(), "Pipe example renders all entities")
	pipes.queue_free()
	await process_frame
	print("Runtime: %d failures" % failures)
	quit(1 if failures else 0)
