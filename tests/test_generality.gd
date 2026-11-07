extends SceneTree
var checks = 0
var failures = 0

func _init() -> void:
	_test_spatial_authoring()
	_test_rule_validation()
	_test_references()
	_test_action_history()
	_test_rule_authoring_tools()
	_test_planes()
	_test_named_fields()
	_test_playtest_entry()
	_test_reference_default_isolation()
	_test_rejected_resolution()
	_test_reference_roundtrip()
	_test_authoring_configuration()
	_test_linked_policy_copy()
	_test_reset_field_draft()
	_test_exact_grid_transforms()
	_test_missing_inherited_references()
	print("Generality: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func _test_spatial_authoring() -> void:
	var definition = GGEntityDefinition.new()
	definition.shape.assign([Vector3i.ZERO, Vector3i.UP])
	var entity = GGEntityPlacement.new()
	entity.definition = definition
	entity.entity_id = &"block"
	entity.quarter_turns = 4
	check(entity.occupied_cells().has(Vector3i.DOWN), "A block can be authored upside down")
	var level = GGLevel.new()
	level.entities.append(entity)
	var authoring = GGLevelAuthoring.new()
	authoring.open(level)
	check(authoring.save("user://oriented.tres") == OK, "Spatial level saves")
	var loaded = ResourceLoader.load("user://oriented.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(loaded.entities[0].occupied_cells().has(Vector3i.DOWN), "Full orientation survives save and reload")

class OverlapRule extends GGGameRule:
	func validate_level(_level: GGLevel) -> PackedStringArray:
		return []

func _test_rule_validation() -> void:
	var level = GGLevel.new()
	level.game_rule = OverlapRule.new()
	var definition = GGEntityDefinition.new()
	for id in [&"a", &"b"]:
		var entity = GGEntityPlacement.new()
		entity.entity_id = id
		entity.definition = definition
		entity.cell = Vector3i(0, -20, 0)
		level.entities.append(entity)
	check(level.validate().is_empty(), "Games can author overlapping entities below the default fall-out plane")

func _test_references() -> void:
	var field_script = load("res://addons/grid_game_groundwork/data/property_field.gd")
	check(field_script != null, "Games can declare named entity reference fields")
	if field_script == null: return
	var field = field_script.new()
	field.key = &"target"
	field.label = "Destination"
	field.kind = 5
	var definition = GGEntityDefinition.new()
	definition.fields.append(field)
	var level = GGLevel.new()
	level.gravity_enabled = false
	for pair in [[&"a", Vector3i.ZERO], [&"b", Vector3i(3, 0, 0)]]:
		var entity = GGEntityPlacement.new()
		entity.entity_id = pair[0]
		entity.cell = pair[1]
		entity.definition = definition
		level.entities.append(entity)
	level.entities[0].overrides["target"] = &"b"
	var editor = GGLevelAuthoring.new()
	editor.open(level)
	var copies = editor.duplicate_entities([&"a", &"b"])
	check(copies.size() == 2, "Linked group duplicates")
	if copies.size() != 2: return
	check(editor.find_entity(copies[0]).resolved_properties().target == copies[1], "Internal links point to the corresponding group copy")
	editor.erase(&"b")
	check(not level.validate().is_empty(), "Deleting a referenced target prevents playtesting")
	check(editor.save("user://linked_draft.tres") == OK, "A broken-link draft can still save")
	check(editor.save_playtest("user://broken_playtest.tres") == ERR_INVALID_DATA, "Broken-link drafts cannot start playtesting")
	check(editor.undo() and level.validate().is_empty(), "Undo deletion repairs the original reference")

class DirectionRule extends GGGameRule:
	func resolve_action(session: GGSession, command: StringName, arguments: Dictionary) -> bool:
		if command == &"gravity":
			session.mechanic_state["gravity_direction"] = arguments.direction
			return session.call("settle")
		if command == &"overlap":
			session.entities[&"actor"].cell = session.entities[&"wall"].cell
			return true
		if command == &"reject":
			session.entities.clear()
			return false
		return false

func _test_action_history() -> void:
	var level = GGLevel.new()
	level.gravity_enabled = false
	level.game_rule = DirectionRule.new()
	var actor = GGEntityPlacement.new()
	actor.entity_id = &"actor"
	actor.definition = GGEntityDefinition.new()
	var wall = GGEntityPlacement.new()
	wall.entity_id = &"wall"
	wall.cell = Vector3i(3, 0, 0)
	wall.definition = GGEntityDefinition.new()
	wall.definition.definition_id = &"wall"
	wall.definition.movable = false
	level.entities.assign([actor, wall])
	var session = GGSession.new()
	check(session.start(level).is_empty(), "Directional gravity fixture loads")
	check(session.has_method("act"), "Games can submit commands to shared action history")
	if not session.has_method("act"): return
	var initial = session.snapshot()
	check(session.call("act", &"gravity", {"direction": Vector3i.RIGHT}), "A game command switches gravity and settles the board")
	check(session.entities[&"actor"].cell == Vector3i(2, 0, 0), "Sideways gravity lands against a wall")
	var resolved = session.snapshot()
	check(not session.act(&"overlap") and session.snapshot() == resolved, "Invalid resolved occupancy rolls back before entering history")
	check(session.undo() and session.snapshot() == initial, "One undo restores gravity and every resulting fall")
	check(not session.call("act", &"reject", {}) and session.snapshot() == initial, "Rejected custom commands restore all state")
	check(session.redo() and session.snapshot() == resolved, "Rejected commands preserve the redo branch")

func _test_rule_authoring_tools() -> void:
	var level = GGLevel.new()
	level.game_rule = OverlapRule.new()
	var definition = GGEntityDefinition.new()
	var editor = GGLevelAuthoring.new()
	editor.open(level)
	check(editor.paint(definition, Vector3i.ZERO), "First custom-rule placement succeeds")
	check(editor.paint(definition, Vector3i.ZERO), "Second custom-rule placement succeeds")
	check(level.entities.back().cell == Vector3i.ZERO, "Auto placement respects games that allow overlapping entities")

func _test_planes() -> void:
	var editor = GGLevelAuthoring.new()
	editor.open(GGLevel.new())
	var stroke = GGEditorStroke.new(editor)
	stroke.configure(GGEntityDefinition.new(), 0, 0, false, true)
	check(stroke.has_method("set_plane"), "Authoring supports choosing a placement plane")
	if not stroke.has_method("set_plane"): return
	stroke.call("set_plane", Vector3i.BACK)
	check(stroke.preview(Vector3(2, 3, 10), Vector3.FORWARD, 4) == Vector3i(2, 3, 4), "XY placement fixes Z while retaining X and Y")
	stroke.call("set_plane", Vector3i.RIGHT)
	check(stroke.preview(Vector3(10, 3, 2), Vector3.LEFT, 4) == Vector3i(4, 3, 2), "YZ placement fixes X while retaining Y and Z")

func _test_named_fields() -> void:
	var script = load("res://addons/grid_game_groundwork/editor/fields_editor.gd")
	check(script != null, "The editor provides named fields and entity selectors")
	if script == null: return
	var form = script.new()
	var field = GGPropertyField.new()
	field.key = &"target"
	field.label = "Destination"
	field.kind = GGPropertyField.Kind.ENTITY
	var definition = GGEntityDefinition.new()
	definition.fields.append(field)
	var level = GGLevel.new()
	var source = GGEntityPlacement.new()
	source.entity_id = &"source"
	source.definition = definition
	var target = GGEntityPlacement.new()
	target.entity_id = &"destination"
	target.definition = definition
	level.entities.assign([source, target])
	var overrides = {}
	form.configure(level, source, overrides)
	var toggle = form.get_node("target/Override")
	toggle.button_pressed = true
	var picker = form.get_node("target/Input")
	var index = -1
	for item in picker.item_count:
		if picker.get_item_metadata(item) == &"destination": index = item
	check(index >= 0, "Designers can choose a target entity from available entities")
	if index >= 0: picker.item_selected.emit(index)
	check(overrides.get(&"target") == &"destination", "Choosing a target creates a typed entity override")
	toggle.button_pressed = false
	check(not overrides.has(&"target"), "Disabling an override restores inheritance")
	form.free()

func _test_playtest_entry() -> void:
	var authoring = GGLevelAuthoring.new()
	var level = GGLevel.new()
	level.title = "Unsaved test"
	authoring.open(level)
	check(authoring.has_method("prepare_playtest"), "The editor can prepare a configured playtest entry")
	if not authoring.has_method("prepare_playtest"): return
	var path = authoring.call("prepare_playtest", "user://generality_playtest")
	check(not path.is_empty(), "Playtest preparation writes a launchable scene")
	var packed = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var host = packed.instantiate()
	check(host.level.title == "Unsaved test" and host.level != level, "Playtest receives an isolated snapshot of unsaved configuration")
	host.free()

func _test_reference_default_isolation() -> void:
	var field = GGPropertyField.new()
	field.key = &"links"
	field.kind = GGPropertyField.Kind.ENTITIES
	field.default_value = [&"target"]
	var definition = GGEntityDefinition.new()
	definition.fields.append(field)
	var level = GGLevel.new()
	level.gravity_enabled = false
	for pair in [[&"source", Vector3i.ZERO], [&"target", Vector3i.RIGHT]]:
		var entity = GGEntityPlacement.new()
		entity.entity_id = pair[0]
		entity.cell = pair[1]
		entity.definition = definition
		level.entities.append(entity)
	var session = GGSession.new()
	check(session.start(level).is_empty(), "A shared reference-default fixture loads")
	session.entities[&"source"].properties[&"links"].append(&"new_runtime_link")
	check(field.default_value == [&"target"], "Runtime reference edits never mutate authored defaults")
	check(session.entities[&"target"].properties[&"links"] == [&"target"], "Runtime reference edits do not leak to another entity")

class EndlessFallRule extends DirectionRule:
	func is_outside(_session: GGSession, _id: StringName, _direction: Vector3i) -> bool:
		return false

func _test_rejected_resolution() -> void:
	var level = GGLevel.new()
	level.gravity_enabled = false
	var rule = EndlessFallRule.new()
	rule.resolution_limit = 3
	level.game_rule = rule
	var actor = GGEntityPlacement.new()
	actor.entity_id = &"actor"
	actor.definition = GGEntityDefinition.new()
	level.entities.append(actor)
	var session = GGSession.new()
	check(session.start(level).is_empty(), "A gravity-disabled bounded-resolution fixture loads")
	var initial = session.snapshot()
	check(not session.act(&"gravity", {"direction": Vector3i.RIGHT}), "Unbounded gravity rejects the whole action")
	check(session.snapshot() == initial and not session.undo(), "Failed settlement leaves no partial state or history")

func _test_reference_roundtrip() -> void:
	var editor = GGLevelAuthoring.new()
	editor.open(ResourceLoader.load("res://tests/fixtures/entity_references.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP))
	var copies = editor.duplicate_entities([&"source"])
	check(copies.size() == 1, "An entity with a reference can be copied independently")
	if copies.is_empty(): return
	check(editor.find_entity(copies[0]).resolved_properties()[&"target"] == &"target", "References outside a copied group remain unchanged")
	check(editor.save("user://copied_references.tres") == OK, "A level with copied links saves")
	var loaded = ResourceLoader.load("user://copied_references.tres", "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	check(loaded.validate().is_empty() and loaded.schema_version == 2, "References and the upgraded schema survive reload")
	editor.open(loaded)
	var deleted_id = editor.level.entities.back().entity_id
	var definition = editor.level.entities.back().definition
	check(editor.erase(deleted_id), "A copied entity can be deleted")
	check(editor.paint(definition, Vector3i(8, 0, 3)), "A new entity can be painted after deletion")
	check(editor.level.entities.back().entity_id != deleted_id, "New entities do not reuse a deleted identity")

class PaletteRule extends GGGameRule:
	func validate_level(level: GGLevel) -> PackedStringArray:
		for entity in level.entities:
			if not level.palette.has(entity.definition): return PackedStringArray(["Definition must belong to this game's palette."])
		return super.validate_level(level)

func _test_authoring_configuration() -> void:
	var level = GGLevel.new()
	level.game_rule = PaletteRule.new()
	var definition = GGEntityDefinition.new()
	level.palette.append(definition)
	var authoring = GGLevelAuthoring.new()
	authoring.open(level)
	check(authoring.paint(definition, Vector3i.ZERO), "Placement policies receive the full authored level configuration")

class LinkedPlacementRule extends GGGameRule:
	func validate_level(level: GGLevel) -> PackedStringArray:
		var errors = super.validate_level(level)
		for entity in level.entities:
			var target = entity.resolved_properties().get(&"target", &"")
			for other in level.entities:
				if target == other.entity_id and other.cell - entity.cell != Vector3i(2, 0, 0):
					errors.append("Linked entities must remain two cells apart.")
		return errors

func _test_linked_policy_copy() -> void:
	var field = GGPropertyField.new()
	field.key = &"target"
	field.kind = GGPropertyField.Kind.ENTITY
	var definition = GGEntityDefinition.new()
	definition.fields.append(field)
	var level = GGLevel.new()
	level.game_rule = LinkedPlacementRule.new()
	for pair in [[&"source", Vector3i.ZERO], [&"target", Vector3i(2, 0, 0)]]:
		var entity = GGEntityPlacement.new()
		entity.entity_id = pair[0]
		entity.cell = pair[1]
		entity.definition = definition
		level.entities.append(entity)
	level.entities[0].overrides[&"target"] = &"target"
	var editor = GGLevelAuthoring.new()
	editor.open(level)
	check(level.validate().is_empty(), "A game-defined linked-placement policy accepts the source layout")
	var copies = editor.duplicate_entities([&"source", &"target"])
	check(copies.size() == 2 and level.validate().is_empty(), "Group copying validates the remapped relationships instead of stale original targets")

func _test_reset_field_draft() -> void:
	var field = GGPropertyField.new()
	field.key = &"mass"
	field.kind = GGPropertyField.Kind.FLOAT
	field.default_value = 2.0
	var definition = GGEntityDefinition.new()
	definition.fields.append(field)
	var entity = GGEntityPlacement.new()
	entity.definition = definition
	entity.overrides[&"mass"] = 9.0
	var form = GGFieldsEditor.new()
	var reset_draft = {}
	form.configure(GGLevel.new(), entity, reset_draft)
	check(form.get_node("mass/Input").value == 2.0, "Reset fields display inherited defaults instead of the entity's prior override")
	form.get_node("mass/Override").button_pressed = true
	check(reset_draft.get(&"mass") == 2.0, "Re-enabling a reset field starts with its displayed inherited value")
	form.get_node("mass/Input").value = 5.0
	form.get_node("mass/Override").button_pressed = false
	check(form.get_node("mass/Input").value == 2.0 and not reset_draft.has(&"mass"), "Disabling a field visibly restores inheritance")
	form.free()

func _test_exact_grid_transforms() -> void:
	var entity = GGEntityPlacement.new()
	entity.entity_id = &"distant"
	entity.definition = GGEntityDefinition.new()
	entity.definition.shape.assign([Vector3i.ZERO, Vector3i(16777217, 0, 0)])
	entity.cell = Vector3i(16777217, 1, 16777219)
	var original = entity.cell
	var level = GGLevel.new()
	level.entities.append(entity)
	var editor = GGLevelAuthoring.new()
	editor.open(level)
	check(entity.occupied_cells().has(Vector3i(33554434, 1, 16777219)), "Occupied cells retain integer precision beyond float mantissa range")
	for turn in 4: editor.transform_level(false)
	check(entity.cell == original, "Four world-axis turns exactly restore distant integer coordinates")

func _test_missing_inherited_references() -> void:
	var definition = GGEntityDefinition.new()
	definition.definition_id = &"linked"
	for kind in [GGPropertyField.Kind.ENTITY, GGPropertyField.Kind.ENTITIES]:
		var field = GGPropertyField.new()
		field.key = &"target" if kind == GGPropertyField.Kind.ENTITY else &"targets"
		field.kind = kind
		field.default_value = &"deleted" if kind == GGPropertyField.Kind.ENTITY else [&"deleted"]
		definition.fields.append(field)
	var source = GGEntityPlacement.new()
	source.entity_id = &"source"
	source.definition = definition
	source.overrides = {&"target": &"valid", &"targets": [&"valid"]}
	var target = GGEntityPlacement.new()
	target.entity_id = &"valid"
	target.cell = Vector3i.RIGHT
	target.definition = GGEntityDefinition.new()
	var level = GGLevel.new()
	level.entities.assign([source, target])
	check(level.validate().is_empty(), "Explicit valid references can cover missing inherited defaults")
	var form = GGFieldsEditor.new()
	var draft = source.overrides.duplicate(true)
	form.configure(level, source, draft)
	form.get_node("target/Override").button_pressed = false
	var picker = form.get_node("target/Input") as OptionButton
	check(picker.get_item_metadata(picker.selected) == &"deleted" and picker.get_item_text(picker.selected).begins_with("Missing:"), "Disabling a reference override reveals its actual missing inherited target")
	form.get_node("targets/Override").button_pressed = false
	var list = form.get_node("targets/Input") as ItemList
	var selected = list.get_selected_items()
	check(selected.size() == 1 and list.get_item_metadata(selected[0]) == &"deleted" and list.get_item_text(selected[0]).begins_with("Missing:"), "Reference lists reveal missing inherited targets when overrides are disabled")
	form.free()
