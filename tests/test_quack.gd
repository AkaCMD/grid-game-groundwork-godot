extends SceneTree

var failures = 0
var checks = 0
const SOLUTION = [[&"duck_a", Vector3i.RIGHT], [&"duck_a", Vector3i.LEFT], [&"duck_b", Vector3i.RIGHT], [&"duck_c", Vector3i.RIGHT], [&"duck_a", Vector3i.FORWARD], [&"duck_c", Vector3i.LEFT], [&"duck_c", Vector3i.BACK]]
const DESTINATIONS = [Vector3i(3, 0, 1), Vector3i(0, 0, 1), Vector3i(2, 0, 3), Vector3i(3, 0, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(1, 0, 2)]

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fresh() -> GGSession:
	var session = GGSession.new()
	check(session.start(load("res://examples/levels/quack.tres")).is_empty(), "QUACK level validates")
	return session

func run() -> void:
	var session = fresh()
	var initial = session.snapshot()
	check(session.select_actor(&"duck_b") and session.player_id() == &"duck_b", "Player selection changes the controlled actor")
	check(not session.select_actor(&"bread_a") and not session.select_actor(&"missing"), "Selection rejects non-players and missing entities")
	check(session.snapshot() == initial and not session.undo(), "Selection is outside action history")
	for i in range(SOLUTION.size()):
		var before = session.snapshot()
		var id: StringName = SOLUTION[i][0]
		check(session.move(id, SOLUTION[i][1]), "Solution step %d succeeds" % (i + 1))
		check(session.entities[id].cell == DESTINATIONS[i], "Solution step %d stops at its verified cell" % (i + 1))
		var after = session.snapshot()
		if i == 0:
			check(not session.entities.has(&"bread_a") and session.entities[id].state.fed, "Eating removes bread and feeds the duck")
			var landing = false
			var continued = false
			for stage in session.stages:
				if stage.entities[id].cell == Vector3i(0, 0, 1): landing = true
				if landing and stage.entities[id].cell == Vector3i(1, 0, 1): continued = true
			check(landing and continued, "Slide lands two cells below and continues horizontally")
		check(session.undo() and session.snapshot() == before, "One undo restores the complete slide")
		check(session.player_id() == &"duck_b", "Undo does not change selected actor")
		check(session.redo() and session.snapshot() == after, "Redo restores the entire slide without replaying rules")
	check(session.status == &"won", "Seven-move walkthrough wins")
	session.restart()
	check(session.snapshot() == initial, "Restart restores all hungry ducks, bread and status")
	check(session.undo() and session.status == &"won", "Restart remains undoable")
	check(session.redo() and session.snapshot() == initial, "Restart can be redone")
	check(session.move(&"duck_a", Vector3i.FORWARD) and session.status == &"failed", "Sliding off the upper platform causes fall-out failure")
	check(not session.entities.has(&"duck_a"), "Fallen duck is removed")
	check(session.undo() and session.snapshot() == initial, "Undo restores a fallen duck and playing state")
	check(session.redo() and session.status == &"failed", "Redo restores fall-out failure")
	check(not can_solve(true), "Level cannot be solved without moving a fed duck")
	check(not can_solve(false), "Level cannot be solved without stopping against another duck")
	test_bread_and_blockers()
	test_authoring()
	await test_runtime()
	print("QUACK: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_bread_and_blockers() -> void:
	var session = fresh()
	session.move(&"duck_a", Vector3i.RIGHT)
	session.move(&"duck_a", Vector3i.LEFT)
	var before = session.snapshot()
	check(not session.move(&"duck_c", Vector3i.BACK), "Ducks block other ducks without pushing")
	check(session.snapshot() == before, "A blocked move changes no state")
	# Move bread into the fed duck's path using a separate authored fixture.
	var level: GGLevel = load("res://examples/levels/quack.tres").duplicate(true)
	for placement in level.entities:
		if placement.entity_id == &"bread_b": placement.cell = Vector3i(2, 0, 1)
	check(session.start(level).is_empty(), "Bread-blocking fixture validates")
	# Eat the first bread in the lane, then try to pass the second one.
	check(session.move(&"duck_a", Vector3i.RIGHT), "Hungry duck stops at the first bread")
	check(session.entities[&"duck_a"].cell == Vector3i(2, 0, 1), "Hungry duck immediately stops on eating")
	before = session.snapshot()
	check(not session.move(&"duck_a", Vector3i.RIGHT) and session.snapshot() == before, "Bread blocks a fed duck and is not consumed")
	check(session.undo() and not session.entities[&"duck_a"].state.get("fed", false), "Blocked slide adds no history entry")
	# Nonterminating slides in gravity-disabled edited boards are rejected atomically.
	level.gravity_enabled = false
	check(session.start(level).is_empty(), "Gravity-disabled fixture validates")
	before = session.snapshot()
	check(not session.move(&"duck_a", Vector3i.LEFT) and session.snapshot() == before, "Unbounded slide terminates without partial state or history")

func test_authoring() -> void:
	var authoring = GGLevelAuthoring.new()
	authoring.open(load("res://examples/levels/quack.tres"))
	check(authoring.edit_entity(&"duck_b", Vector3i(1, 0, 3), 0, false, {}), "QUACK entities can be edited through existing authoring")
	check(authoring.undo() and authoring.find_entity(&"duck_b").cell == Vector3i(0, 0, 3), "QUACK authoring edit is undoable")
	check(authoring.save("user://quack-roundtrip.tres") == OK, "QUACK saves using existing authoring")
	var level: GGLevel = load("user://quack-roundtrip.tres")
	check(level.validate().is_empty() and level.palette.size() == 4, "QUACK reloads with its shared palette")
	var session = GGSession.new()
	check(session.start(level).is_empty(), "Saved QUACK can be playtested")
	for command in SOLUTION: session.move(command[0], command[1])
	check(session.status == &"won", "Saved and reloaded level retains its rules and solution")

func test_runtime() -> void:
	var game: GGGame = load("res://examples/quack.tscn").instantiate()
	root.add_child(game)
	await process_frame
	check(game._view.roots.size() == game.level.entities.size(), "Runtime renders every QUACK entity")
	# Project a visible duck's center to exercise the real mouse selection path.
	var click = InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	click.position = game._camera.unproject_position(Vector3(0, 0.4, 3))
	game._unhandled_input(click)
	check(game.session.player_id() == &"duck_b", "Click selects the duck under the cursor")
	check(game._view._selection.visible and game._view._selected == &"duck_b", "Selected duck has a visible highlight")
	var visual = game._view.roots[&"duck_a"].get_child(0)
	check(visual.get_child_count() == 6, "Cube has six textured faces")
	for face in visual.get_children():
		check(face.material_override.get_shader_parameter("sprite").resource_path.ends_with("duck.png"), "Every face uses the original hungry texture")
	check(visual.get_child(0).material_override.get_shader_parameter("background_color") == Color.WHITE, "Unselected duck has a white background")
	var selected_visual = game._view.roots[&"duck_b"].get_child(0)
	check(selected_visual.get_child(0).material_override.get_shader_parameter("background_color") == Color.BLACK, "Selected duck has a black background")
	game.session.move(&"duck_a", Vector3i.RIGHT)
	game._view.show_state(game.session.snapshot())
	check(not game._view.roots.has(&"bread_a"), "Eaten bread disappears from view")
	check(visual.get_child(0).material_override.get_shader_parameter("sprite").resource_path.ends_with("stuffed_duck.png"), "Fed appearance follows simulation state")
	game.session.undo()
	game._view.show_state(game.session.snapshot())
	check(game._view.roots.has(&"bread_a") and visual.get_child(0).material_override.get_shader_parameter("sprite").resource_path.ends_with("duck.png"), "Undo restores bread and hungry appearance")
	game.queue_free()
	await process_frame

func can_solve(freeze_fed: bool) -> bool:
	# Exhaust the actual simulation, forbidding one required cooperation at a time.
	var session = fresh()
	var frontier: Array[Dictionary] = [session.snapshot()]
	var visited = {}
	var cursor = 0
	while cursor < frontier.size():
		var state = frontier[cursor]
		cursor += 1
		for id in [&"duck_a", &"duck_b", &"duck_c"]:
			if freeze_fed and state.entities[id].state.get("fed", false):
				continue
			for direction in [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.BACK, Vector3i.FORWARD]:
				session.undo()
				session.restore(state)
				if not session.move(id, direction) or session.status == &"failed":
					continue
				var just_ate = session.entities[id].state.get("fed", false) and not state.entities[id].state.get("fed", false)
				if not freeze_fed and not just_ate:
					var stopped_by_duck = false
					for blocker in session.blockers(id, direction):
						if session.entities[blocker].properties.get("player", false): stopped_by_duck = true
					if stopped_by_duck: continue
				if session.status == &"won": return true
				var key = []
				for duck in [&"duck_a", &"duck_b", &"duck_c"]:
					key.append(session.entities[duck].cell)
					key.append(session.entities[duck].state.get("fed", false))
				for bread in [&"bread_a", &"bread_b", &"bread_c"]:
					key.append(session.entities.has(bread))
				var signature = str(key)
				if not visited.has(signature):
					visited[signature] = true
					frontier.append(session.snapshot())
	return false
