extends SceneTree
var checks = 0
var failures = 0

func _init() -> void:
	_test_stacking_and_history()
	_test_shapes_and_transforms()
	_test_save_and_overrides()
	_test_validation()
	_test_exact_paint()
	_test_group_delete()
	_test_group_duplicate()
	_test_group_move()
	_test_move_preview()
	_test_snap_to_ground()
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

func _test_exact_paint() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	editor.paint(crate, Vector3i.ZERO)
	var history = editor._history.size()
	editor.dirty = false
	check(not editor.paint_exact(crate, Vector3i.ZERO) and editor.last_error.contains("overlap"), "Exact paint refuses solid overlap instead of auto-stacking")
	check(not editor.dirty and editor._history.size() == history and editor.level.entities.size() == 1, "Rejected exact paint has no side effects")
	check(editor.paint_exact(crate, Vector3i.ZERO, 1, true, {"solid": false, "weight": 7}), "Exact paint respects a non-solid override")
	check(editor.level.entities.back().cell == Vector3i.ZERO and editor.level.entities.back().mirrored, "Exact paint retains position, orientation and overrides")
	check(not editor.paint_exact(crate, Vector3i(2, -8, 0), 0, false, {"solid": false}), "Non-solid exact paint also respects the fall-out height")
	check(not editor.paint_exact(crate, Vector3i.ZERO, 1, true, {"solid": false}), "Exact paint preserves non-solid duplicate prevention")

func _test_move_preview() -> void:
	var editor = author()
	var definition = editor.level.palette[3]
	definition.shape.assign([Vector3i.ZERO, Vector3i.RIGHT])
	editor.paint(definition, Vector3i.ZERO, 1, true, {"weight": 7.0})
	editor.paint(definition, Vector3i(3, 0, 0))
	var entity = editor.level.entities[0]
	var history_size = editor._history.size()
	editor.dirty = false
	check(editor.position_error(entity.entity_id, Vector3i(3, 0, 0)) != "", "Move preview rejects a destination overlapping another solid")
	check(editor.position_error(entity.entity_id, Vector3i(0, -8, 0)) != "", "Move preview rejects the fall-out height")
	check(editor.position_error(entity.entity_id, Vector3i(6, 0, 0)) == "", "Editor moves can cross obstacles to a free destination")
	check(entity.cell == Vector3i.ZERO and not editor.dirty and editor._history.size() == history_size, "Preview validation leaves authored coordinates, dirty state and history untouched")
	check(entity.quarter_turns == 1 and entity.mirrored and entity.overrides.weight == 7.0, "Preview preserves orientation and overrides")
	check(editor.edit_entity(entity.entity_id, Vector3i(6, 0, 0), entity.quarter_turns, entity.mirrored, entity.overrides), "A validated multi-cell destination can be committed")
	check(editor.undo() and editor.find_entity(entity.entity_id).cell == Vector3i.ZERO, "One undo restores the complete moved entity")
	check(editor.redo() and editor.find_entity(entity.entity_id).cell == Vector3i(6, 0, 0), "One redo reapplies the complete move")
	check(editor.save("user://moved_level.tres") == OK, "Moved entity saves")
	var reloaded = ResourceLoader.load("user://moved_level.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(reloaded.entities[0].cell == Vector3i(6, 0, 0) and reloaded.entities[0].quarter_turns == 1 and reloaded.entities[0].mirrored and reloaded.entities[0].overrides.weight == 7.0, "Save/reload preserves moved coordinates, orientation and overrides")
	editor.edit_entity(entity.entity_id, Vector3i(6, 0, 0), 1, true, {"solid": false})
	check(editor.position_error(entity.entity_id, Vector3i(3, 0, 0)) == "", "Non-solid entities may preview shared occupancy")

func _test_snap_to_ground() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	crate.shape.assign([Vector3i.ZERO, Vector3i.RIGHT, Vector3i(0, -2, 0)])
	editor.paint(crate, Vector3i(2, 9, 2), 1, true, {"weight": 7.0})
	var entity = editor.level.entities[0]
	var cells = entity.occupied_cells()
	var ground = editor.level.palette[0]
	editor.paint(ground, cells[2] + Vector3i.DOWN * 6)
	var original = entity.cell
	var history_size = editor._history.size()
	editor.dirty = false
	var target = editor.ground_position(entity.entity_id, entity.cell)
	check(target == entity.cell + Vector3i.DOWN * 5, "Snap uses the complete rotated/mirrored shape, including cells below the origin")
	check(entity.cell == Vector3i(2, 9, 2) and not editor.dirty and editor._history.size() == history_size, "Ground query leaves authored data, dirty state and history untouched")
	check(editor.ground_position(entity.entity_id, entity.cell + Vector3i.UP * 1000000) == target, "Ground search handles large heights without stepping through empty cells")
	# A higher support under the overhanging arm catches the whole entity first.
	editor.paint(ground, cells[1] + Vector3i.DOWN * 3)
	var higher_target = entity.cell + Vector3i.DOWN * 2
	check(editor.ground_position(entity.entity_id, entity.cell) == higher_target, "Any supported shape cell holds the whole rigid entity at the nearest surface")
	check(editor.ground_position(entity.entity_id, higher_target) == higher_target, "Already supported snap is a no-op")
	check(editor.ground_position(entity.entity_id, entity.cell + Vector3i.RIGHT * 50) == null and editor.last_error.contains("No supporting surface"), "No support returns a message instead of an invisible floor")
	var support_cell = editor.level.entities.back().cell
	check(editor.ground_position(entity.entity_id, support_cell) == null and editor.last_error.contains("overlapping"), "Snap rejects a currently overlapping preview")
	editor.edit_entity(editor.level.entities.back().entity_id, support_cell, 0, false, {"solid": false})
	check(editor.ground_position(entity.entity_id, entity.cell) == target, "Non-solid entities do not catch a falling selection")
	editor.level.gravity_enabled = false
	check(editor.ground_position(entity.entity_id, entity.cell) == target, "Authoring snap works with gameplay gravity disabled")
	check(editor.edit_entity(entity.entity_id, target, 1, true, entity.overrides), "Grounded destination can be committed")
	check(editor.undo() and editor.find_entity(entity.entity_id).cell == original, "Snap undo restores the original position")
	check(editor.redo() and editor.find_entity(entity.entity_id).cell == target, "Snap redo restores the grounded position")
	var moved = editor.find_entity(entity.entity_id)
	check(moved.quarter_turns == 1 and moved.mirrored and moved.overrides.weight == 7.0, "Snap preserves orientation and overrides")
	check(editor.ground_position(&"missing", Vector3i.ZERO) == null, "Snap handles an absent selection")

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

func _test_group_move() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	editor.paint(crate, Vector3i.ZERO, 1, true, {"weight": 7.0})
	editor.paint(crate, Vector3i.RIGHT)
	editor.paint(crate, Vector3i(3, 0, 0))
	var first = editor.level.entities[0].entity_id
	var second = editor.level.entities[1].entity_id
	var ids: Array[StringName] = [first, second]
	editor.dirty = false
	check(editor.translation_error(ids, Vector3i.RIGHT).is_empty(), "Group preview allows cells vacated by selected entities")
	check(editor.find_entity(first).cell == Vector3i.ZERO and editor.find_entity(second).cell == Vector3i.RIGHT and not editor.dirty, "Group preview leaves authored data untouched")
	check(not editor.translate_entities(ids, Vector3i(2, 0, 0)), "One blocked member rejects the entire group move")
	check(editor.find_entity(first).cell == Vector3i.ZERO and editor.find_entity(second).cell == Vector3i.RIGHT, "Rejected group move restores every member")
	check(editor.translate_entities(ids, Vector3i.RIGHT), "Group moves simultaneously into vacated cells")
	check(editor.find_entity(first).cell == Vector3i.RIGHT and editor.find_entity(second).cell == Vector3i(2, 0, 0), "Group move preserves relative positions")
	check(editor.undo() and editor.find_entity(first).cell == Vector3i.ZERO and editor.find_entity(second).cell == Vector3i.RIGHT, "One undo restores the entire group")
	check(editor.redo() and editor.find_entity(second).cell == Vector3i(2, 0, 0), "One redo reapplies the entire group")
	var moved = editor.find_entity(first)
	check(moved.quarter_turns == 1 and moved.mirrored and moved.overrides.weight == 7.0, "Group move preserves orientation and overrides")
	check(not editor.translate_entities([first, &"missing"], Vector3i.UP) and moved.cell == Vector3i.RIGHT, "Stale group members fail atomically")

func _test_group_duplicate() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	crate.shape.assign([Vector3i.ZERO, Vector3i(0, -2, 0)])
	editor.paint(crate, Vector3i(0, 2, 0), 1, true, {"weight": 7.0})
	editor.paint(crate, Vector3i(1, 2, 0))
	var first = editor.level.entities[0].entity_id
	var second = editor.level.entities[1].entity_id
	var copies = editor.duplicate_entities([first, second])
	check(copies.size() == 2 and editor.level.entities.size() == 4, "Duplicate creates every selected entity")
	if copies.size() != 2: return
	var copied = editor.find_entity(copies[0])
	check(copied.cell == Vector3i(1, 3, 0) and editor.find_entity(copies[1]).cell == Vector3i(2, 3, 0), "Duplicate lifts the whole group to the first free position, preserving spacing and downward shapes")
	check(copied.definition == crate and copied.quarter_turns == 1 and copied.mirrored and copied.overrides.weight == 7.0, "Duplicate preserves shared definition, orientation and explicit overrides")
	copied.overrides.weight = 9.0
	check(editor.find_entity(first).overrides.weight == 7.0, "Duplicate owns an independent override dictionary")
	check(copies[0] != first and copies[1] != second and copies[0] != copies[1], "Every duplicate receives a fresh unique ID")
	check(editor.undo() and editor.level.entities.size() == 2, "One undo removes all copies")
	check(editor.redo() and editor.find_entity(copies[1]) != null, "Redo restores all copies and their IDs")
	check(editor.duplicate_entities([first, &"missing"]).is_empty() and editor.level.entities.size() == 4, "Duplicate rejects stale selections without partial copies")
	editor.level.schema_version = 2
	check(editor.duplicate_entities([first, second]).is_empty() and editor.level.entities.size() == 4, "Invalid level rejects duplicate atomically")

func _test_group_delete() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	editor.paint(crate, Vector3i.ZERO)
	editor.paint(crate, Vector3i.RIGHT)
	editor.paint(editor.level.palette[4], Vector3i.ZERO)
	var first = editor.level.entities[0].entity_id
	var second = editor.level.entities[1].entity_id
	check(not editor.erase_entities([first, &"missing"]) and editor.level.entities.size() == 3, "Stale selection cannot cause partial deletion")
	check(editor.erase_entities([first, second, first]) and editor.level.entities.size() == 1, "Group delete removes each selected entity once, retaining unselected non-solid entities")
	check(editor.undo() and editor.level.entities.size() == 3 and editor.find_entity(first) != null and editor.find_entity(second) != null, "One undo restores the whole deleted group")
	check(editor.redo() and editor.level.entities.size() == 1, "One redo deletes the whole group")
	check(not editor.erase_entities([]), "Empty deletion does not create an edit")
	check(editor.undo() and editor.level.entities.size() == 3, "Failed empty deletion does not consume an undo action")
