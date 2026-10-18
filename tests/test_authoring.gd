extends SceneTree
var checks = 0
var failures = 0

func _init() -> void:
	_test_stacking_and_history()
	_test_shapes_and_transforms()
	_test_save_and_overrides()
	_test_validation()
	_test_discard_and_unsaved_playtest()
	_test_external_rule_save()
	print("Authoring: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error(message)

func author() -> GGLevelAuthoring:
	var level = GGLevel.new()
	level.palette = GGDefaults.palette()
	var result = GGLevelAuthoring.new()
	result.open(level)
	return result

func _test_stacking_and_history() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	check(editor.paint(crate, Vector3i.ZERO), "Can paint an entity")
	check(editor.paint(crate, Vector3i.ZERO), "Can paint onto an occupied cell")
	check(editor.level.entities[1].cell == Vector3i.UP, "Painting occupied cells stacks automatically")
	check(editor.undo() and editor.level.entities.size() == 1, "Authoring undo removes the new entity")
	check(editor.redo() and editor.level.entities.size() == 2, "Authoring redo restores it")
	editor.begin_stroke()
	editor.paint(crate, Vector3i(3, 0, 0))
	editor.paint(crate, Vector3i(4, 0, 0))
	editor.paint(crate, Vector3i(5, 0, 0))
	editor.end_stroke()
	check(editor.undo() and editor.level.entities.size() == 2, "A continuous brush stroke is one undo action")
	check(editor.redo() and editor.level.entities.size() == 5, "A stroke can be redone as a whole")
	var id = editor.level.entities[0].entity_id
	check(editor.erase(id) and not editor.find_entity(id), "Can erase an entity")
	check(editor.undo() and editor.find_entity(id) != null, "Erase is undoable")
	var goal = editor.level.palette[4]
	check(editor.paint(goal, Vector3i.ZERO), "Can paint a non-solid goal under a crate")
	check(editor.level.entities.back().cell == Vector3i.ZERO, "Non-solid placement does not stack")
	check(not editor.paint(goal, Vector3i.ZERO), "Dragging does not duplicate the same non-solid entity")
	var ground = editor.level.palette[0]
	var floor_editor = author()
	floor_editor.fill_floor(ground, Vector3i(0, -1, 0), 3, 2)
	check(floor_editor.level.entities.size() == 6, "Floor fill paints the requested rectangle")
	floor_editor.fill_floor(ground, Vector3i(0, -1, 0), 3, 2)
	check(floor_editor.level.entities.size() == 6, "Filling again skips occupied cells")
	check(floor_editor.undo() and floor_editor.level.entities.is_empty(), "Entire floor fill is one action")

func _test_shapes_and_transforms() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	check(editor.edit_shape(crate, Vector3i.RIGHT, false), "Visual shape editing adds a cell")
	check(crate.shape.size() == 2, "The reusable shape includes added cells")
	check(editor.undo() and crate.shape.size() == 1, "Shape edits participate in authoring undo")
	check(editor.redo() and crate.shape.size() == 2, "Shape edits participate in redo")
	check(editor.edit_shape(crate, Vector3i.RIGHT, true), "Can remove a shape cell")
	check(not editor.edit_shape(crate, Vector3i.ZERO, true), "Cannot erase the final occupied cell")
	editor.edit_shape(crate, Vector3i(0, -2, 0), false)
	editor.edit_shape(crate, Vector3i.DOWN, false)
	editor.paint(crate, Vector3i.ZERO)
	editor.paint(crate, Vector3i.ZERO)
	check(editor.level.entities[1].cell == Vector3i(0, 3, 0), "Auto-stacking handles shapes extending below their origin")
	var transformed = author()
	crate = transformed.level.palette[3]
	crate.shape.assign([Vector3i.ZERO, Vector3i.RIGHT, Vector3i(0, 0, -1)])
	transformed.paint(crate, Vector3i(2, 0, 3))
	transformed.transform_level(false)
	var cells = transformed.level.entities[0].occupied_cells()
	check(cells.has(Vector3i(-3, 0, 2)) and cells.has(Vector3i(-3, 0, 3)) and cells.has(Vector3i(-2, 0, 2)), "Level rotation transforms placement and occupied shape together")
	transformed.transform_level(true)
	cells = transformed.level.entities[0].occupied_cells()
	check(cells.has(Vector3i(3, 0, 2)) and cells.has(Vector3i(3, 0, 3)) and cells.has(Vector3i(2, 0, 2)), "Mirroring transforms cell occupancy rather than only visuals")
	check(transformed.level.validate().is_empty(), "Transformed level remains valid")

func _test_save_and_overrides() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	editor.paint(crate, Vector3i.ZERO)
	editor.paint(crate, Vector3i(2, 0, 0), 1, true, {"weight": 4.0})
	crate.properties.weight = 2.0
	check(editor.level.entities[0].resolved_properties().weight == 2.0, "Unmodified entities inherit changed defaults")
	check(editor.level.entities[1].resolved_properties().weight == 4.0, "Explicit overrides survive default changes")
	check(editor.save("user://authoring_test.tres") == OK, "Can save a native level")
	check(not editor.dirty, "Successful save clears unsaved status")
	var loaded = ResourceLoader.load("user://authoring_test.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(loaded is GGLevel and loaded.entities.size() == 2, "Saved level reloads")
	check(loaded.entities[0].definition == loaded.entities[1].definition, "Saving preserves shared definition identity")
	check(loaded.entities[0].overrides.is_empty(), "Saving does not flatten defaults into overrides")
	check(loaded.entities[1].overrides.weight == 4.0, "Overrides persist")
	check(loaded.entities[1].quarter_turns == 1 and loaded.entities[1].mirrored, "Rotation and mirroring persist")
	editor.transform_level(true)
	check(editor.save("user://authoring_test.tres") == OK, "Can overwrite an existing saved level")
	var second = ResourceLoader.load("user://authoring_test.tres", "", ResourceLoader.CACHE_MODE_IGNORE)
	check(second.entities[1].cell == Vector3i(-2, 0, 0), "Overwrite saves the latest transformed state")

func _test_validation() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	editor.paint(crate, Vector3i.ZERO)
	editor.paint(crate, Vector3i.RIGHT)
	var id = editor.level.entities[1].entity_id
	check(not editor.edit_entity(id, Vector3i.ZERO, 0, false, {}), "Selection edits reject solid overlap")
	check(editor.find_entity(id).cell == Vector3i.RIGHT, "Rejected edit leaves original state intact")
	check(editor.edit_entity(id, Vector3i.RIGHT, 0, false, {"solid": false}), "An entity can override solid behavior")
	check(editor.edit_entity(id, Vector3i.ZERO, 0, false, {"solid": false}), "A non-solid override allows shared occupancy")
	editor.level.entities[1].entity_id = editor.level.entities[0].entity_id
	check(not editor.level.validate().is_empty(), "Duplicate entity IDs are rejected")
	check(editor.save("user://invalid.tres") == ERR_INVALID_DATA, "Invalid levels cannot overwrite a saved file")
	var missing = GGEntityPlacement.new()
	editor.level.entities.append(missing)
	check(not editor.level.validate().is_empty(), "Missing definitions produce validation messages")

func _test_discard_and_unsaved_playtest() -> void:
	var editor = author()
	var definition = editor.level.palette[3]
	var definition_path = "user://shared_crate.tres"
	check(ResourceSaver.save(definition, definition_path) == OK, "External definition fixture saves")
	definition.take_over_path(definition_path)
	editor.paint(definition, Vector3i.ZERO)
	var rule = GGGameRule.new()
	rule.push_rule = GGStrengthPushRule.new()
	check(ResourceSaver.save(rule, "user://shared_rule.tres") == OK, "External rule fixture saves")
	rule.take_over_path("user://shared_rule.tres")
	editor.set_rule(rule)
	check(editor.save("user://discard_level.tres") == OK, "Discard fixture level saves")
	editor.edit_shape(definition, Vector3i.RIGHT, false)
	definition.properties = {"weight": 9.0}
	rule.push_rule = GGPushRule.new()
	editor.paint(definition, Vector3i(4, 0, 0))
	check(editor.save_playtest("user://live_playtest.tres") == OK, "Unsaved level can be prepared for playtest")
	var played = ResourceLoader.load("user://live_playtest.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(played.entities[0].definition.shape.size() == 2, "Playtest includes unsaved external shape edits")
	check(played.entities[0].resolved_properties().weight == 9.0, "Playtest includes unsaved external default properties")
	check(not played.game_rule.push_rule is GGStrengthPushRule, "Playtest includes unsaved external rule configuration")
	var disk_definition = ResourceLoader.load(definition_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(disk_definition.shape.size() == 1, "Preparing a playtest does not save authored definitions")
	check(editor.discard_changes(), "Unsaved level and shared configuration edits can be discarded")
	var reopened = load("user://discard_level.tres")
	check(reopened.entities.size() == 1, "Discard then reopen does not resurrect discarded placements")
	check(reopened.entities[0].definition.shape.size() == 1, "Discard restores cached shared shapes")
	check(reopened.entities[0].resolved_properties().weight == 1.0, "Discard restores cached shared defaults")
	check(reopened.game_rule.push_rule is GGStrengthPushRule, "Discard restores cached shared game rules")
	check(not editor.dirty, "Discard clears dirty state after restoring cached resources")

func _test_external_rule_save() -> void:
	var editor = author()
	var rule = GGGameRule.new()
	var push = GGStrengthPushRule.new()
	push.set_meta("designer_setting", 1)
	check(ResourceSaver.save(push, "user://nested_push.tres") == OK, "Nested push-rule fixture saves")
	push.take_over_path("user://nested_push.tres")
	rule.push_rule = push
	check(ResourceSaver.save(rule, "user://external_game_rule.tres") == OK, "Game-rule fixture saves")
	rule.take_over_path("user://external_game_rule.tres")
	editor.set_rule(rule)
	push.set_meta("designer_setting", 5)
	check(editor.contains_configuration(push), "External nested rules belong to editable level configuration")
	check(editor.save("user://rule_level.tres") == OK, "Save persists nested external configuration")
	var loaded = ResourceLoader.load("user://rule_level.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(loaded.game_rule.push_rule.get_meta("designer_setting") == 5, "Fresh reload retains nested push-rule edits")
	rule.push_rule = GGPushRule.new()
	check(editor.save("user://rule_level.tres") == OK, "Save persists external game-rule edits")
	loaded = ResourceLoader.load("user://rule_level.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(not loaded.game_rule.push_rule is GGStrengthPushRule, "Fresh reload uses the newly selected push policy")
