extends SceneTree

class EndingRule extends GGGameRule:
	var ending: StringName = &"won"

	func after_action(session: GGSession) -> void:
		if session.entities[&"player"].cell.x >= 2:
			session.status = ending

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
	await test_input_buffer()
	print("Runtime: %d failures" % failures)
	quit(1 if failures else 0)

func press(game: GGGame, key: Key, echo: bool = false) -> void:
	var event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	event.echo = echo
	game._unhandled_key_input(event)

func wait_for_idle(game: GGGame) -> void:
	for frame in range(240):
		if not game._busy:
			return
		await process_frame
	check(false, "Buffered animation finishes within the frame limit")

func test_input_buffer() -> void:
	var level = GGLevel.new()
	level.gravity_enabled = false
	var player = GGEntityPlacement.new()
	player.entity_id = &"player"
	player.definition = load("res://examples/entities/player.tres")
	level.entities.append(player)
	var game = GGGame.new()
	game.level = level
	game.step_duration = 0.2
	game.buffered_step_duration = 0.05
	root.add_child(game)
	await process_frame
	var rapid_start = Time.get_ticks_msec()
	press(game, KEY_D)
	press(game, KEY_W)
	press(game, KEY_A)
	check(game.session.entities[&"player"].cell == Vector3i.RIGHT, "Buffered commands wait for the active action")
	await wait_for_idle(game)
	var rapid_elapsed = Time.get_ticks_msec() - rapid_start
	check(game.session.entities[&"player"].cell == Vector3i(0, 0, -1), "Rapid direction changes execute in input order")
	check(game._view.roots[&"player"].position == Vector3(0, 0, -1), "Visual position catches up with buffered movement")
	game._history_action("Undo")
	await wait_for_idle(game)
	check(game.session.entities[&"player"].cell == Vector3i(1, 0, -1), "Each buffered move remains a separate undoable action")
	game._history_action("Redo")
	await wait_for_idle(game)
	check(game.session.entities[&"player"].cell == Vector3i(0, 0, -1), "Buffered movement can be redone")
	var held_start = Time.get_ticks_msec()
	press(game, KEY_D)
	for i in range(12):
		press(game, KEY_D, true)
	check(game._move_queue.is_empty(), "Held key repeats do not accumulate buffered movement")
	await wait_for_idle(game)
	var held_elapsed = Time.get_ticks_msec() - held_start
	check(held_elapsed >= 350, "Held key repeats keep the normal animation speed")
	check(rapid_elapsed < held_elapsed, "Three rapid taps animate faster than one normal move")
	press(game, KEY_D)
	for i in range(12):
		press(game, KEY_D)
	check(game._move_queue.size() == GGGame.INPUT_BUFFER_LIMIT, "Input buffer has a fixed limit")
	await wait_for_idle(game)
	check(game.session.entities[&"player"].cell == Vector3i(6, 0, -1), "Excess taps do not cause an unbounded movement backlog")
	for action in ["Undo", "Redo", "Restart"]:
		press(game, KEY_W)
		press(game, KEY_D)
		var before_history = game.session.snapshot()
		game._history_action(action)
		check(game._move_queue.is_empty(), "History controls discard buffered movement")
		await wait_for_idle(game)
		if action == "Undo":
			check(game.session.entities[&"player"].cell == Vector3i(6, 0, -1), "Undo pressed during animation runs after the active action")
		elif action == "Restart":
			check(game.session.entities[&"player"].cell == Vector3i.ZERO, "Restart pressed during animation restores the start without stale movement")
		else:
			check(game.session.snapshot() == before_history, "Unavailable redo discards stale movement and leaves the current action intact")
	# A blocked queued command must not prevent the next direction from executing.
	var wall = GGEntityPlacement.new()
	wall.entity_id = &"wall"
	wall.definition = load("res://examples/entities/wall.tres")
	wall.cell = Vector3i(2, 0, 0)
	level.entities.append(wall)
	game.queue_free()
	await process_frame
	game = GGGame.new()
	game.level = level
	root.add_child(game)
	await process_frame
	press(game, KEY_D)
	press(game, KEY_D)
	press(game, KEY_W)
	await wait_for_idle(game)
	check(game.session.entities[&"player"].cell == Vector3i(1, 0, -1), "A blocked buffered move does not stall later inputs")
	game.queue_free()
	await process_frame

	level.entities.erase(wall)
	for ending in [&"won", &"failed"]:
		var rule = EndingRule.new()
		rule.ending = ending
		level.game_rule = rule
		game = GGGame.new()
		game.level = level
		root.add_child(game)
		await process_frame
		press(game, KEY_D)
		press(game, KEY_D)
		press(game, KEY_D)
		await wait_for_idle(game)
		check(game.session.status == ending, "Buffered moves resolve terminal game rules")
		check(game.session.entities[&"player"].cell == Vector3i(2, 0, 0) and game._move_queue.is_empty(), "Winning or failing clears remaining buffered movement")
		game._history_action("Undo")
		await wait_for_idle(game)
		check(game.session.status == &"playing" and game.session.entities[&"player"].cell == Vector3i.RIGHT, "Undo after a terminal buffered action restores play without stale input")
		game.queue_free()
		await process_frame
