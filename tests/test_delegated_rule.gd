extends SceneTree

const Implementation = preload("res://tests/fixtures/delegated_rule_implementation.gd")
var failures = 0

func _init() -> void:
	_test_configuration()
	_test_playtest_history()
	print("Delegated rules: %d failures" % failures)
	quit(1 if failures else 0)

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func _test_configuration() -> void:
	var level = GGLevel.new()
	var rule = GGDelegatedGameRule.new()
	level.game_rule = rule
	check(not level.validate().is_empty(), "A delegated rule needs an implementation")
	rule.implementation = Resource.new()
	check(not level.validate().is_empty(), "An unavailable implementation must not silently use the default rule")
	rule.implementation = Implementation.new()
	check(level.validate().has("This layout requires gravity to be disabled."), "The implementation can reject a layout")
	level.gravity_enabled = false
	level.entities.append(_actor())
	level.entities[0].cell.y = level.void_height
	check(not level.validate().is_empty(), "Delegated validation still enforces default layout bounds")

func _test_playtest_history() -> void:
	var level = GGLevel.new()
	level.gravity_enabled = false
	level.entities.append(_actor())
	var rule = GGDelegatedGameRule.new()
	var implementation = Implementation.new()
	rule.implementation = implementation
	level.game_rule = rule
	var authoring = GGLevelAuthoring.new()
	authoring.open(level)
	if authoring.save("user://delegated_rule_test.tres") != OK:
		check(false, "The delegated implementation saves with the level")
		return
	var reloaded = ResourceLoader.load("user://delegated_rule_test.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP) as GGLevel
	if not reloaded:
		check(false, "The delegated implementation reloads with the level")
		return
	authoring.open(reloaded)
	# Playtest should use the live configuration, including edits made since saving.
	(reloaded.game_rule as GGDelegatedGameRule).implementation.set("limit", 2)
	var entry_path = authoring.prepare_playtest("user://delegated_rule_test")
	if entry_path.is_empty():
		check(false, "The delegated rule can be prepared for playtest: " + authoring.last_error)
		return
	var entry = (load(entry_path) as PackedScene).instantiate() as GGPlaytest
	var session = GGSession.new()
	var errors = session.start(entry.level)
	entry.free()
	if not errors.is_empty():
		check(false, "The playtest snapshot can start a session: " + "\n".join(errors))
		return
	check(session.entities_at(Vector3i.UP) == [&"actor"], "The occupancy query includes the entity's entire shape")
	var tags: Array = session.get_entity_property(&"actor", &"tags")
	tags.clear()
	check(session.get_entity_property(&"actor", &"tags") == ["test"], "Property queries do not expose live arrays")
	check(not session.set_mechanic_state(&"count", 0), "State writes require an active resolution")
	check(session.act(&"increment") and session.act(&"increment"), "Playtest uses the unsaved implementation settings")
	check(not session.act(&"increment") and session.get_mechanic_state(&"count") == 2, "Rejected commands roll back state writes")
	check(session.undo() and session.get_mechanic_state(&"count") == 1, "Undo restores the preceding mechanic state")
	check(not session.act(&"unknown"), "The rule rejects unhandled commands")
	check(session.redo() and session.get_mechanic_state(&"count") == 2, "Rejected commands preserve the redo branch")
	check(session.move(&"actor", Vector3i.RIGHT), "The built-in move command still works")

func _actor() -> GGEntityPlacement:
	var actor = GGEntityPlacement.new()
	actor.entity_id = &"actor"
	actor.definition = GGEntityDefinition.new()
	actor.definition.shape.assign([Vector3i.ZERO, Vector3i.UP])
	actor.definition.properties = {"tags": ["test"]}
	return actor
