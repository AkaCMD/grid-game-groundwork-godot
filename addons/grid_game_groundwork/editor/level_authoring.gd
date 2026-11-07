@tool
class_name GGLevelAuthoring
extends RefCounted
## Public authoring boundary, shared by the editor UI and save/load tests.

signal changed
signal stroke_ended
signal level_opened
const LevelConfiguration = preload("res://addons/grid_game_groundwork/editor/level_configuration.gd")
var level: GGLevel
var dirty = false
var placement_normal = Vector3i.UP
var last_error: String = ""
var _history: Array[Dictionary] = []
var _future: Array[Dictionary] = []
var _stroke = false
var _stroke_recorded = false

func open(value: GGLevel) -> void:
	end_stroke()
	level = value
	level.migrate()
	_history.clear()
	_future.clear()
	dirty = false
	level_opened.emit()
	changed.emit()

func discard_changes() -> bool:
	var configuration = LevelConfiguration.new(level)
	if not configuration.restore_saved():
		last_error = configuration.last_error
		return false
	_history.clear()
	_future.clear()
	end_stroke()
	dirty = false
	changed.emit()
	return true

func contains_configuration(resource: Resource) -> bool:
	return LevelConfiguration.new(level).contains(resource)

func save_playtest(path: String) -> Error:
	var errors = level.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return ERR_INVALID_DATA
	# Bundle live definitions and rule configuration, including unsaved external
	# resources, so the separate game process sees exactly the current design.
	var isolated: GGLevel = LevelConfiguration.new(level).isolated_level()
	var error = ResourceSaver.save(isolated, path)
	last_error = "" if error == OK else "Could not prepare playtest (error %d)." % error
	return error

func prepare_playtest(directory: String) -> String:
	var error = DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(directory))
	if error != OK:
		last_error = "Could not create playtest directory."
		return ""
	var resource_path = directory.path_join("playtest.tres")
	if save_playtest(resource_path) != OK: return ""
	var entry = GGPlaytest.new()
	entry.name = "Playtest"
	entry.level = ResourceLoader.load(resource_path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
	var packed = PackedScene.new()
	error = packed.pack(entry)
	entry.free()
	var scene_path = directory.path_join("playtest.tscn")
	if error == OK: error = ResourceSaver.save(packed, scene_path)
	if error != OK:
		last_error = "Could not prepare playtest scene."
		return ""
	return scene_path

func set_playtest_scene(scene: PackedScene) -> void:
	_record()
	level.playtest_scene = scene
	_notify()

func snapshot() -> Dictionary:
	var shapes = {}
	for definition in level.palette:
		shapes[definition] = definition.shape.duplicate()
	return {"entities": level.copy_entities(), "palette": level.palette.duplicate(), "shapes": shapes, "title": level.title, "gravity": level.gravity_enabled, "void": level.void_height, "rule": level.game_rule, "host": level.playtest_scene}

func _restore(state: Dictionary) -> void:
	level.entities.clear()
	for entity in state.entities:
		level.entities.append(entity.copy())
	level.palette.assign(state.palette)
	for definition in state.shapes:
		definition.shape.assign(state.shapes[definition])
		definition.emit_changed()
	level.title = state.title
	level.gravity_enabled = state.gravity
	level.void_height = state.void
	level.game_rule = state.rule
	level.playtest_scene = state.host
	_notify()

func begin_stroke() -> void:
	end_stroke()
	_stroke = true
	_stroke_recorded = false

func end_stroke() -> void:
	var was_active = _stroke
	_stroke = false
	_stroke_recorded = false
	if was_active: stroke_ended.emit()

func _record() -> void:
	if not _stroke or not _stroke_recorded:
		_history.append(snapshot())
		_future.clear()
		_stroke_recorded = true

func _notify() -> void:
	dirty = true
	level.emit_changed()
	changed.emit()

func _proposed_level(candidates: Array[GGEntityPlacement]) -> GGLevel:
	# Keep the level's configuration and shared definitions, but isolate every
	# placement so rule validation cannot expose trial edits through live data.
	var proposed: GGLevel = level.duplicate(false)
	proposed.entities = []
	var replacements = {}
	for candidate in candidates: replacements[candidate.entity_id] = candidate
	for entity in level.entities:
		if entity and replacements.has(entity.entity_id):
			proposed.entities.append(replacements[entity.entity_id].copy())
			replacements.erase(entity.entity_id)
		else:
			proposed.entities.append(entity.copy() if entity else null)
	for candidate in replacements.values(): proposed.entities.append(candidate.copy())
	return proposed

func _proposal_error(candidates: Array[GGEntityPlacement]) -> String:
	return "\n".join(_proposed_level(candidates).validate_placement())

func _commit_placements(candidates: Array[GGEntityPlacement], finish_stroke: bool = true) -> bool:
	last_error = _proposal_error(candidates)
	if not last_error.is_empty(): return false
	return _apply_placements(candidates, finish_stroke)

func _apply_placements(candidates: Array[GGEntityPlacement], finish_stroke: bool) -> bool:
	if finish_stroke: end_stroke()
	_record()
	for candidate in candidates:
		var existing = find_entity(candidate.entity_id)
		if existing:
			# Accepted edits retain the Resource identity used by the Inspector.
			existing.cell = candidate.cell
			existing.orientation = candidate.orientation
			existing.mirrored = candidate.mirrored
			existing.overrides = candidate.overrides.duplicate(true)
		else:
			level.entities.append(candidate)
	_notify()
	return true

func _translated(entities: Array[GGEntityPlacement], offset: Vector3i) -> Array[GGEntityPlacement]:
	var candidates: Array[GGEntityPlacement] = []
	for entity in entities:
		var candidate = entity.copy()
		candidate.cell += offset
		candidates.append(candidate)
	return candidates

func placement_cell(definition: GGEntityDefinition, cell: Vector3i, turns: int = 0, mirrored: bool = false, overrides: Dictionary = {}) -> Variant:
	var candidate = _paint_candidate(definition, cell, turns, mirrored, overrides)
	return candidate.cell if _lift_paint(candidate).is_empty() else null

func _lift_paint(candidate: GGEntityPlacement) -> String:
	var cell = candidate.cell
	var error = _proposal_error([candidate])
	if error.is_empty() or candidate.definition.shape.is_empty(): return error
	for lift in _lift_offsets([candidate]).slice(1):
		candidate.cell = cell + placement_normal * lift
		if _proposal_error([candidate]).is_empty(): return ""
	candidate.cell = cell
	return error

func _lift_offsets(candidates: Array[GGEntityPlacement]) -> Array:
	# Only occupied cells can end a collision interval. Sparse distant terrain
	# must not turn a rejected placement into a walk through empty space.
	var offsets = {0: true}
	for entity in level.entities:
		if not entity: continue
		for used in entity.occupied_cells():
			for candidate in candidates:
				for cell in candidate.occupied_cells():
					var delta = used - cell
					var height = GGGrid.dot(delta, placement_normal)
					if height >= 0 and delta == placement_normal * height: offsets[height + 1] = true
	var result = offsets.keys()
	result.sort()
	return result

func paint(definition: GGEntityDefinition, cell: Vector3i, turns: int = 0, mirrored: bool = false, overrides: Dictionary = {}) -> bool:
	return _paint(_paint_candidate(definition, cell, turns, mirrored, overrides), true)

func placement_error(definition: GGEntityDefinition, cell: Vector3i, turns: int = 0, mirrored: bool = false, overrides: Dictionary = {}) -> String:
	return _paint_error(_paint_candidate(definition, cell, turns, mirrored, overrides), false)

func paint_exact(definition: GGEntityDefinition, cell: Vector3i, turns: int = 0, mirrored: bool = false, overrides: Dictionary = {}) -> bool:
	return _paint(_paint_candidate(definition, cell, turns, mirrored, overrides), false)

func _paint_candidate(definition: GGEntityDefinition, cell: Vector3i, turns: int, mirrored: bool, overrides: Dictionary) -> GGEntityPlacement:
	var candidate = GGEntityPlacement.new()
	candidate.entity_id = _next_id(definition.definition_id)
	candidate.definition = definition
	candidate.cell = cell
	candidate.orientation = turns
	candidate.mirrored = mirrored
	candidate.overrides = overrides.duplicate(true)
	return candidate

func _paint(candidate: GGEntityPlacement, lift: bool) -> bool:
	last_error = _paint_error(candidate, lift)
	return last_error.is_empty() and _apply_placements([candidate], false)

func _paint_error(candidate: GGEntityPlacement, lift: bool) -> String:
	if lift:
		var error = _lift_paint(candidate)
		if not error.is_empty(): return error
	# A duplicate is refused at the chosen cell, even in automatic mode.
	for existing in level.entities:
		if existing and existing.definition == candidate.definition and existing.cell == candidate.cell and existing.orientation == candidate.orientation and not existing.resolved_properties().get("solid", true):
			return "%s is already placed at %s." % [candidate.definition.display_name, candidate.cell]
	return "" if lift else _proposal_error([candidate])

func _next_id(prefix: StringName) -> StringName:
	return StringName("%s_%s" % [prefix, ResourceUID.id_to_text(ResourceUID.create_id()).trim_prefix("uid://")])

func find_entity(id: StringName) -> GGEntityPlacement:
	for entity in level.entities:
		if entity.entity_id == id:
			return entity
	return null

func erase(id: StringName) -> bool:
	var entity = find_entity(id)
	if not entity:
		return false
	_record()
	level.entities.erase(entity)
	_notify()
	return true

func position_error(id: StringName, cell: Vector3i) -> String:
	var entity = find_entity(id)
	if not entity:
		return "Select an entity first."
	var candidate = entity.copy()
	candidate.cell = cell
	return _proposal_error([candidate])

func _selected_entities(ids: Array[StringName]) -> Array[GGEntityPlacement]:
	var result: Array[GGEntityPlacement] = []
	for id in ids:
		var entity = find_entity(id)
		if not entity:
			last_error = "Selected entity no longer exists: %s" % id
			return []
		if not result.has(entity): result.append(entity)
	last_error = "" if not result.is_empty() else "Select an entity first."
	return result

func erase_entities(ids: Array[StringName]) -> bool:
	var entities = _selected_entities(ids)
	if entities.is_empty(): return false
	end_stroke()
	_record()
	for entity in entities: level.entities.erase(entity)
	_notify()
	return true

func translation_error(ids: Array[StringName], offset: Vector3i) -> String:
	var entities = _selected_entities(ids)
	if entities.is_empty(): return last_error
	return _proposal_error(_translated(entities, offset))

func translate_entities(ids: Array[StringName], offset: Vector3i) -> bool:
	var entities = _selected_entities(ids)
	if entities.is_empty(): return false
	if offset == Vector3i.ZERO:
		last_error = _proposal_error([])
		return false
	return _commit_placements(_translated(entities, offset))

func duplicate_entities(ids: Array[StringName]) -> Array[StringName]:
	var sources = _selected_entities(ids)
	if sources.is_empty(): return []
	last_error = _proposal_error([])
	if not last_error.is_empty(): return []
	var copies: Array[GGEntityPlacement] = []
	var identities = {}
	for source in sources:
		var copied = source.copy()
		copied.cell += Vector3i.RIGHT
		copied.entity_id = _next_id(copied.definition.definition_id)
		identities[source.entity_id] = copied.entity_id
		copies.append(copied)
	for copied in copies:
		for field in copied.definition.fields:
			if field and field.kind in [GGPropertyField.Kind.ENTITY, GGPropertyField.Kind.ENTITIES]:
				var value = copied.resolved_properties().get(field.key)
				var mapped = field.remap(value, identities)
				if mapped != value: copied.overrides[field.key] = mapped
	var bases = copies.map(func(entity): return entity.cell)
	var found = false
	for lift in _lift_offsets(copies):
		for index in copies.size(): copies[index].cell = bases[index] + placement_normal * lift
		if _proposal_error(copies).is_empty():
			found = true
			break
	if not found:
		last_error = "No valid destination for the copied group."
		return []
	var result: Array[StringName] = []
	for copied in copies:
		result.append(copied.entity_id)
	return result if _commit_placements(copies) else []

func ground_position(id: StringName, cell: Vector3i) -> Variant:
	last_error = position_error(id, cell)
	if not last_error.is_empty():
		last_error = "Cannot snap an invalid position; move out of overlapping cells first.\n" + last_error
		return null
	var entity = find_entity(id)
	var candidate = entity.copy()
	candidate.cell = cell
	var cells = candidate.occupied_cells()
	var direction = level.rule().authoring_gravity(level)
	if direction == Vector3i.ZERO:
		last_error = "No support direction configured."
		return null
	var distance = 0
	var found = false
	for other in level.entities:
		if other.entity_id == id or not level.rule().supports_placement(level, candidate, other, direction): continue
		for support in other.occupied_cells():
			for occupied in cells:
				var delta = support - occupied
				var projected = GGGrid.dot(delta, direction)
				if projected <= 0 or delta != direction * projected: continue
				var gap = projected - 1
				if not found or gap < distance:
					distance = gap
					found = true
	if not found:
		last_error = "No supporting surface below the selected entity."
		return null
	var target = cell + direction * distance
	last_error = position_error(id, target)
	return target if last_error.is_empty() else null

func edit_entity(id: StringName, cell: Vector3i, turns: int, mirrored: bool, overrides: Dictionary) -> bool:
	var entity = find_entity(id)
	if not entity:
		return false
	var candidate = entity.copy()
	candidate.cell = cell
	candidate.quarter_turns = posmod(turns, 24)
	candidate.mirrored = mirrored
	candidate.overrides = overrides.duplicate(true)
	return _commit_placements([candidate], false)

func edit_settings(title: String, gravity: bool, void_height: int) -> void:
	_record()
	level.title = title
	level.gravity_enabled = gravity
	level.void_height = void_height
	_notify()

func set_rule(rule: GGGameRule) -> void:
	_record()
	level.game_rule = rule
	_notify()

func add_definition(definition: GGEntityDefinition) -> void:
	if level.palette.has(definition):
		return
	_record()
	level.palette.append(definition)
	_notify()

func edit_shape(definition: GGEntityDefinition, cell: Vector3i, remove: bool) -> bool:
	if remove and (not definition.shape.has(cell) or definition.shape.size() == 1):
		return false
	if not remove and definition.shape.has(cell):
		return false
	_record()
	if remove:
		definition.shape.erase(cell)
	else:
		definition.shape.append(cell)
	definition.emit_changed()
	_notify()
	return true

func transform_level(mirror: bool) -> void:
	_record()
	for entity in level.entities:
		entity.cell = GGGrid.transform_cell(entity.cell, 0 if mirror else 1, mirror)
		if mirror:
			var reflection = Basis.from_scale(Vector3(-1, 1, 1))
			entity.orientation = GGGrid.orientation_index(reflection * GGGrid.orientation_basis(entity.orientation) * reflection)
			entity.mirrored = not entity.mirrored
		else:
			entity.orientation = GGGrid.rotated(entity.orientation, Vector3i.UP)
	_notify()

func fill_floor(definition: GGEntityDefinition, origin: Vector3i, width: int, depth: int) -> void:
	begin_stroke()
	for x in width:
		for z in depth:
			var axes = [Vector3i.RIGHT, Vector3i.BACK] if placement_normal == Vector3i.UP else ([Vector3i.RIGHT, Vector3i.UP] if placement_normal == Vector3i.BACK else [Vector3i.UP, Vector3i.BACK])
			var cell = origin + axes[0] * x + axes[1] * z
			if placement_error(definition, cell).is_empty():
				paint_exact(definition, cell)
	end_stroke()

func undo() -> bool:
	end_stroke()
	if _history.is_empty():
		return false
	_future.append(snapshot())
	_restore(_history.pop_back())
	return true

func redo() -> bool:
	end_stroke()
	if _future.is_empty():
		return false
	_history.append(snapshot())
	_restore(_future.pop_back())
	return true

func save(path: String) -> Error:
	var errors = level.validate_structure()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return ERR_INVALID_DATA
	var configuration = LevelConfiguration.new(level)
	var error = configuration.save(path)
	last_error = configuration.last_error
	if error == OK:
		dirty = false
		changed.emit()
	return error
