extends SceneTree
var checks = 0
var failures = 0

func _init() -> void:
	call_deferred("run")

func run() -> void:
	_test_rolling()
	_test_blocked_roll()
	_test_rolling_precision()
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

func _test_blocked_roll() -> void:
	var level: GGLevel = ResourceLoader.load("res://examples/levels/rolling.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var obstacle = GGEntityPlacement.new()
	obstacle.entity_id = &"ceiling"
	obstacle.definition = level.palette[0]
	obstacle.cell = Vector3i(3, 1, 1)
	level.entities.append(obstacle)
	var session = GGSession.new()
	check(session.start(level).is_empty(), "The blocked roll fixture starts")
	var initial = session.snapshot()
	check(session.move(&"block", Vector3i.RIGHT), "The first roll clears the obstacle")
	var before = session.snapshot()
	var stages = session.stages.duplicate(true)
	check(not session.move(&"block", Vector3i.RIGHT), "The next roll is rejected when its rotated shape overlaps")
	check(session.snapshot() == before and session.stages == stages, "A blocked roll preserves the pose and animation stages")
	check(session.undo() and session.snapshot() == initial, "Only the successful roll enters action history")

func _test_rolling_precision() -> void:
	var level: GGLevel = ResourceLoader.load("res://examples/levels/rolling.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	for entity in level.entities: entity.cell += Vector3i(16777217, 0, 16777219)
	var session = GGSession.new()
	check(session.start(level).is_empty(), "The rolling fixture can use distant integer coordinates")
	check(session.move(&"block", Vector3i.RIGHT), "A distant block can roll without float-based coordinate changes")
	check(session.entities.has(&"block") and session.entities[&"block"].cell == Vector3i(16777218, 0, 16777220), "Rolling preserves the exact translated origin")
	check(session.move(&"block", Vector3i.RIGHT) and session.status == &"won", "The translated puzzle retains its exact two-move solution")
