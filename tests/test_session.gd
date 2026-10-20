extends SceneTree

class CountingRule extends GGGameRule:
	func after_action(session: GGSession) -> void:
		session.mechanic_state["count"] = session.mechanic_state.get("count", 0) + 1
		for entity in session.entities.values():
			entity.state["visits"] = {"count": session.mechanic_state.count}

var checks = 0
var failures = 0

class CarryRule extends GGGameRule:
	func carried_entities(_session: GGSession, _actor_id: StringName, _direction: Vector3i) -> Array:
		return [&"rider"]

func _init() -> void:
	_test_history()
	_test_carrying()
	_test_permissions_and_strength()
	_test_support_and_fallout()
	_test_non_solid_overlap()
	_test_sokoban_goals()
	_test_examples()
	print("Session: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _test_carrying() -> void:
	var actor = definition(&"actor")
	var rider = definition(&"rider")
	var session = setup([placed(&"actor", actor, Vector3i.ZERO), placed(&"rider", rider, Vector3i.UP)], false, CarryRule.new())
	var before = session.snapshot()
	check(session.move(&"actor", Vector3i.RIGHT), "Carrying does not require push permissions")
	check(session.entities[&"rider"].cell == Vector3i(1, 1, 0), "Rule-selected companion moves in the same step")
	check(session.stages[0].entities[&"rider"].cell == Vector3i(1, 1, 0), "Companions share the displacement animation stage")
	check(session.undo() and session.snapshot() == before, "Carrying is part of action history")
	var wall = definition(&"wall")
	wall.movable = false
	session = setup([placed(&"actor", actor, Vector3i.ZERO), placed(&"rider", rider, Vector3i.UP), placed(&"wall", wall, Vector3i(1, 1, 0))], false, CarryRule.new())
	before = session.snapshot()
	check(not session.move(&"actor", Vector3i.RIGHT) and session.snapshot() == before, "A blocked companion cannot move through a wall or partially move the group")
	check(not session.undo(), "Rejected carrying adds no history")

func definition(id: StringName, properties: Dictionary = {}, shape: Array = [Vector3i.ZERO]) -> GGEntityDefinition:
	var result = GGEntityDefinition.new()
	result.definition_id = id
	result.properties = properties
	result.shape.assign(shape)
	return result

func placed(id: StringName, def: GGEntityDefinition, cell: Vector3i, overrides: Dictionary = {}) -> GGEntityPlacement:
	var entity = GGEntityPlacement.new()
	entity.entity_id = id
	entity.definition = def
	entity.cell = cell
	entity.overrides = overrides
	return entity

func setup(items: Array, gravity: bool = false, rule: GGGameRule = null) -> GGSession:
	var level = GGLevel.new()
	level.entities.assign(items)
	level.gravity_enabled = gravity
	level.void_height = -3
	level.game_rule = rule
	var session = GGSession.new()
	check(session.start(level).is_empty(), "Fixture must be a valid level")
	return session

func _test_history() -> void:
	var player = definition(&"player", {"player": true, "can_push": true})
	var crate = definition(&"crate", {"pushable": true})
	var actor = placed(&"player", player, Vector3i.ZERO)
	var rule = CountingRule.new()
	var session = setup([actor, placed(&"crate", crate, Vector3i.RIGHT)], false, rule)
	check(session.move(&"player", Vector3i.RIGHT), "Player pushes a crate")
	check(session.entities[&"crate"].cell == Vector3i(2, 0, 0), "Whole push resolves on the grid")
	check(session.mechanic_state.count == 2, "Mechanics run after action resolution")
	check(session.undo(), "Push can be undone")
	check(session.entities[&"crate"].cell == Vector3i.RIGHT, "Undo restores pushed crate")
	check(session.mechanic_state.count == 1 and session.entities[&"player"].state.visits.count == 1, "Undo restores nested mechanic and entity state")
	check(session.redo(), "Push can be redone")
	check(session.mechanic_state.count == 2, "Redo restores mechanics without executing them twice")
	session.restart()
	check(session.entities[&"player"].cell == Vector3i.ZERO, "Restart restores the starting state")
	check(session.undo() and session.entities[&"crate"].cell == Vector3i(2, 0, 0), "Restart itself is undoable")
	check(session.undo(), "Can go back before the push")
	check(session.move(&"player", Vector3i(0, 0, 1)), "Can create a new action branch")
	check(not session.redo(), "New actions discard abandoned redo branches")
	check(not session.move(&"player", Vector3i(1, 1, 0)), "Diagonal or vertical commands are rejected")
	check(actor.cell == Vector3i.ZERO and not player.properties.has("visits"), "Simulation never mutates authored resources")

func _test_permissions_and_strength() -> void:
	var player = definition(&"player", {"can_push": true, "strength": 2.0})
	var crate = definition(&"crate", {"pushable": true, "transmits_push": false, "weight": 1.0})
	var items = [placed(&"p", player, Vector3i.ZERO), placed(&"a", crate, Vector3i.RIGHT), placed(&"b", crate, Vector3i(2, 0, 0))]
	var session = setup(items)
	check(not session.move(&"p", Vector3i.RIGHT), "Entity permission blocks transmitting a push")
	items[1].overrides = {"transmits_push": true}
	session = setup(items)
	check(session.move(&"p", Vector3i.RIGHT), "Per-entity overrides permit a chain push")
	check(not crate.properties.transmits_push, "Overrides do not mutate shared defaults")
	var rule = GGGameRule.new()
	rule.push_rule = GGStrengthPushRule.new()
	items[2].overrides = {"weight": 2.0}
	session = setup(items, false, rule)
	check(not session.move(&"p", Vector3i.RIGHT), "Strength checks total pushed weight")
	items[0].overrides = {"strength": 3.0}
	session = setup(items, false, rule)
	check(session.move(&"p", Vector3i.RIGHT), "Sufficient strength moves the full chain")
	# Interlocking shapes form a dependency cycle, but must be planned once each.
	var shape_a = definition(&"shape_a", {"can_push": true, "pushable": true}, [Vector3i.ZERO, Vector3i(2, 0, 0)])
	var shape_b = definition(&"shape_b", {"pushable": true}, [Vector3i.ZERO])
	session = setup([placed(&"a", shape_a, Vector3i.ZERO), placed(&"b", shape_b, Vector3i.RIGHT)])
	check(session.move(&"a", Vector3i.RIGHT), "Cyclic shape dependencies terminate and move together")

func _test_support_and_fallout() -> void:
	var ground = definition(&"ground")
	ground.movable = false
	var player = definition(&"player", {"player": true})
	var large = definition(&"large", {}, [Vector3i.ZERO, Vector3i.RIGHT, Vector3i(1, 0, 1)])
	var session = setup([placed(&"ground", ground, Vector3i.DOWN), placed(&"large", large, Vector3i.ZERO)], true)
	check(session.entities[&"large"].cell == Vector3i.ZERO, "Any supported cell holds the entire multi-cell shape")
	session = setup([placed(&"ground", ground, Vector3i.DOWN), placed(&"p", player, Vector3i.ZERO)], true)
	check(session.move(&"p", Vector3i.RIGHT), "Player can move over a gap")
	check(session.status == &"failed" and not session.entities.has(&"p"), "Player falling out ends the attempt")
	check(session.undo() and session.status == &"playing" and session.entities.has(&"p"), "Undo recovers from player fall-out")
	check(session.redo() and session.status == &"failed", "Redo restores failure")
	var crate = definition(&"crate", {"pushable": true})
	player.properties["can_push"] = true
	session = setup([placed(&"g0", ground, Vector3i.DOWN), placed(&"g1", ground, Vector3i(1, -1, 0)), placed(&"p", player, Vector3i.ZERO), placed(&"c", crate, Vector3i.RIGHT)], true)
	check(session.move(&"p", Vector3i.RIGHT), "Crate can be pushed into a bottomless gap")
	check(session.status == &"playing" and not session.entities.has(&"c"), "Non-player fall-out removes the entity without failure")
	check(session.undo() and session.entities[&"c"].cell == Vector3i.RIGHT, "One undo restores a pushed and fallen entity")
	var interlock_a = definition(&"a", {}, [Vector3i.ZERO, Vector3i(1, 1, 0)])
	var interlock_b = definition(&"b", {}, [Vector3i.ZERO, Vector3i(-1, 1, 0)])
	session = setup([placed(&"a", interlock_a, Vector3i.ZERO), placed(&"b", interlock_b, Vector3i.RIGHT)], true)
	check(session.entities.is_empty(), "Mutually interlocked unsupported shapes fall together without hanging")

func _test_non_solid_overlap() -> void:
	var player = definition(&"player")
	var marker = definition(&"goal")
	marker.solid = false
	marker.movable = false
	var session = setup([placed(&"p", player, Vector3i.ZERO), placed(&"goal", marker, Vector3i.RIGHT)])
	check(session.move(&"p", Vector3i.RIGHT), "Non-solid entities do not block movement")
	check(GGGrid.index(session.entities)[Vector3i.RIGHT].size() == 2, "Multiple entities can occupy the same cell")

func _test_sokoban_goals() -> void:
	var crate = definition(&"crate", {"crate": true})
	var goal = definition(&"goal", {"goal": true})
	goal.solid = false
	goal.movable = false
	var items = [placed(&"crate", crate, Vector3i.ZERO), placed(&"goal", goal, Vector3i.ZERO)]
	var session = setup(items + [placed(&"extra", crate, Vector3i.RIGHT)], false, GGSokobanRule.new())
	check(session.status == &"won", "Extra crates do not prevent winning when every goal is covered")
	session = setup(items + [placed(&"empty_goal", goal, Vector3i.RIGHT)], false, GGSokobanRule.new())
	check(session.status == &"playing", "Every goal must be covered even when every crate is on a goal")
	crate.shape.assign([Vector3i.ZERO, Vector3i.RIGHT])
	session = setup(items + [placed(&"second_goal", goal, Vector3i.RIGHT)], false, GGSokobanRule.new())
	check(session.status == &"won", "One multi-cell crate can cover multiple goals")
	session = setup([placed(&"crate", crate, Vector3i.ZERO)], false, GGSokobanRule.new())
	check(session.status == &"playing", "A level without goals does not immediately win")
	session = setup([placed(&"goal", goal, Vector3i.ZERO)], false, GGSokobanRule.new())
	check(session.status == &"playing", "An uncovered goal cannot win without a crate")

func _test_examples() -> void:
	var sokoban = load("res://examples/levels/sokoban.tres")
	var session = GGSession.new()
	check(session.start(sokoban).is_empty(), "Sokoban level loads")
	var stacked_demo_crates = 0
	for entity in session.entities.values():
		if entity.properties.get("pushable", false) and entity.cell.y > 0:
			stacked_demo_crates += 1
	check(stacked_demo_crates == 2, "Two stacked demonstration crates remain in the playable example")
	for direction in [Vector3i.FORWARD, Vector3i.FORWARD, Vector3i.BACK, Vector3i.BACK, Vector3i.BACK, Vector3i.RIGHT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.FORWARD]:
		check(session.move(session.player_id(), direction), "Sokoban solution step is legal")
	check(session.status == &"won", "Sokoban example is solvable with a multi-cell crate")
	check(session.undo() and session.status == &"playing", "Undo reopens a completed puzzle")
	check(session.redo() and session.status == &"won", "Redo restores Sokoban completion with demonstration crates present")
	var pipes = load("res://examples/levels/pipes.tres")
	session = GGSession.new()
	check(session.start(pipes).is_empty(), "Pipe level loads")
	for direction in [Vector3i.FORWARD, Vector3i.BACK, Vector3i.RIGHT, Vector3i.FORWARD]:
		check(session.move(session.player_id(), direction), "Pipe solution step is legal")
	check(session.status == &"won", "Pipe example is solvable")
	check(session.undo() and session.status == &"playing", "Undo restores pipe connectivity")
	check(session.redo() and session.status == &"won", "Redo restores powered destinations")
