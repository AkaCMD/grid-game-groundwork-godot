@tool
class_name GGLevelAuthoring
extends RefCounted
## Public authoring boundary, shared by the editor UI and save/load tests.

signal changed
signal stroke_ended
signal level_opened
var level: GGLevel
var dirty = false
var last_error: String = ""
var _history: Array[Dictionary] = []
var _future: Array[Dictionary] = []
var _stroke = false
var _stroke_recorded = false

func open(value: GGLevel) -> void:
	end_stroke()
	level = value
	_history.clear()
	_future.clear()
	dirty = false
	level_opened.emit()
	changed.emit()

func discard_changes() -> bool:
	# Authoring edits cached resources in place, including shared definitions.
	# Reload external configuration before navigating away so discarded edits
	# cannot leak into another level through ResourceLoader's cache.
	var resources = {}
	_collect_configuration(level, {}, resources)
	for path in resources:
		var saved = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if saved == null:
			last_error = "Could not reload %s while discarding edits." % path
			return false
		_copy_configuration(saved, {}, true)
	_history.clear()
	_future.clear()
	end_stroke()
	dirty = false
	changed.emit()
	return true

func _collect_configuration(value: Variant, visited: Dictionary, resources: Dictionary) -> void:
	if value is Script or value is PackedScene:
		return
	if value is Resource:
		if visited.has(value):
			return
		visited[value] = true
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE:
				_collect_configuration(value.get(property.name), visited, resources)
		var path: String = value.resource_path
		if not path.is_empty() and not path.contains("::") and path.get_extension() in ["tres", "res"]:
			resources[path] = value
	elif value is Array:
		for item in value:
			_collect_configuration(item, visited, resources)
	elif value is Dictionary:
		for item in value.values():
			_collect_configuration(item, visited, resources)

func contains_configuration(resource: Resource) -> bool:
	var visited = {}
	_collect_configuration(level, visited, {})
	return visited.has(resource)

func save_playtest(path: String) -> Error:
	var errors = level.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return ERR_INVALID_DATA
	# Bundle live definitions and rule configuration, including unsaved external
	# resources, so the separate game process sees exactly the current design.
	var isolated: GGLevel = _copy_configuration(level, {})
	var error = ResourceSaver.save(isolated, path)
	last_error = "" if error == OK else "Could not prepare playtest (error %d)." % error
	return error

func _copy_configuration(value: Variant, copies: Dictionary, restore_cached: bool = false) -> Variant:
	# Keep script identities and scene assets external. Bundling scripts would
	# redefine their global class names when the temporary level is loaded.
	if value is Script or value is PackedScene:
		return value
	if value is Resource:
		if copies.has(value):
			return copies[value]
		var copied = value.duplicate(false)
		var path: String = value.resource_path
		if restore_cached and not path.is_empty() and not path.contains("::"):
			copied = ResourceLoader.load(path)
		copies[value] = copied
		for property in value.get_property_list():
			if property.usage & PROPERTY_USAGE_STORAGE:
				copied.set(property.name, _copy_configuration(value.get(property.name), copies, restore_cached))
		return copied
	if value is Array:
		var copied = value.duplicate()
		for index in copied.size():
			copied[index] = _copy_configuration(value[index], copies, restore_cached)
		return copied
	if value is Dictionary:
		var copied = {}
		for key in value:
			copied[key] = _copy_configuration(value[key], copies, restore_cached)
		return copied
	return value

func snapshot() -> Dictionary:
	var shapes = {}
	for definition in level.palette:
		shapes[definition] = definition.shape.duplicate()
	return {"entities": level.copy_entities(), "palette": level.palette.duplicate(), "shapes": shapes, "title": level.title, "gravity": level.gravity_enabled, "void": level.void_height, "rule": level.game_rule}

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

func placement_cell(definition: GGEntityDefinition, cell: Vector3i, turns: int = 0, mirrored: bool = false, overrides: Dictionary = {}) -> Variant:
	if definition.shape.is_empty():
		return null
	var candidate = GGEntityPlacement.new()
	candidate.definition = definition
	candidate.cell = cell
	candidate.quarter_turns = turns
	candidate.mirrored = mirrored
	candidate.overrides = overrides
	if not candidate.resolved_properties().get("solid", true):
		return cell
	var occupied = {}
	var highest = cell.y
	for entity in level.entities:
		if entity.resolved_properties().get("solid", true):
			for used_cell in entity.occupied_cells():
				occupied[used_cell] = true
				highest = maxi(highest, used_cell.y)
	var min_offset = 0
	for offset in definition.shape:
		min_offset = mini(min_offset, offset.y)
	# Finite bound: above the highest occupied cell, even a downward-extending shape fits.
	while candidate.cell.y <= highest - min_offset + 1:
		var overlap = false
		for occupied_cell in candidate.occupied_cells():
			if occupied.has(occupied_cell):
				overlap = true
				break
		if not overlap:
			return candidate.cell
		candidate.cell.y += 1
	return null

func paint(definition: GGEntityDefinition, cell: Vector3i, turns: int = 0, mirrored: bool = false, overrides: Dictionary = {}) -> bool:
	var target = placement_cell(definition, cell, turns, mirrored, overrides)
	if target == null:
		return false
	return _paint_at(definition, target, turns, mirrored, overrides)

func placement_error(definition: GGEntityDefinition, cell: Vector3i, turns: int = 0, mirrored: bool = false, overrides: Dictionary = {}) -> String:
	var candidate = GGEntityPlacement.new()
	candidate.entity_id = _next_id(definition.definition_id)
	candidate.definition = definition
	candidate.cell = cell
	candidate.quarter_turns = turns
	candidate.mirrored = mirrored
	candidate.overrides = overrides
	# Validate a proposed level without temporarily modifying the live resource.
	var proposed = GGLevel.new()
	proposed.schema_version = level.schema_version
	proposed.void_height = level.void_height
	proposed.entities.assign(level.entities)
	proposed.entities.append(candidate)
	return "\n".join(proposed.validate())

func paint_exact(definition: GGEntityDefinition, cell: Vector3i, turns: int = 0, mirrored: bool = false, overrides: Dictionary = {}) -> bool:
	last_error = placement_error(definition, cell, turns, mirrored, overrides)
	if not last_error.is_empty(): return false
	return _paint_at(definition, cell, turns, mirrored, overrides)

func _paint_at(definition: GGEntityDefinition, target: Vector3i, turns: int, mirrored: bool, overrides: Dictionary) -> bool:
	for existing in level.entities:
		if not existing.resolved_properties().get("solid", true) and existing.definition == definition and existing.cell == target and existing.quarter_turns == turns:
			return false
	_record()
	var entity = GGEntityPlacement.new()
	entity.entity_id = _next_id(definition.definition_id)
	entity.definition = definition
	entity.cell = target
	entity.quarter_turns = turns
	entity.mirrored = mirrored
	entity.overrides = overrides.duplicate(true)
	level.entities.append(entity)
	_notify()
	return true

func _next_id(prefix: StringName) -> StringName:
	var used = {}
	for entity in level.entities:
		used[entity.entity_id] = true
	var number = 1
	while used.has(StringName("%s_%d" % [prefix, number])):
		number += 1
	return StringName("%s_%d" % [prefix, number])

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
	# Validate the exact destination, including rotated/mirrored shape cells,
	# without emitting changes or recording a speculative edit in history.
	var original = entity.cell
	entity.cell = cell
	var errors = level.validate()
	entity.cell = original
	return "\n".join(errors)

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
	# Validate every destination simultaneously, excluding all vacated cells.
	for entity in entities: entity.cell += offset
	var errors = level.validate()
	for entity in entities: entity.cell -= offset
	return "\n".join(errors)

func translate_entities(ids: Array[StringName], offset: Vector3i) -> bool:
	last_error = translation_error(ids, offset)
	if not last_error.is_empty() or offset == Vector3i.ZERO: return false
	end_stroke()
	_record()
	for entity in _selected_entities(ids): entity.cell += offset
	_notify()
	return true

func duplicate_entities(ids: Array[StringName]) -> Array[StringName]:
	var sources = _selected_entities(ids)
	if sources.is_empty(): return []
	last_error = "\n".join(level.validate())
	if not last_error.is_empty(): return []
	var copies: Array[GGEntityPlacement] = []
	var columns = {}
	for entity in level.entities:
		if not entity.resolved_properties().get("solid", true): continue
		for cell in entity.occupied_cells():
			var column = Vector2i(cell.x, cell.z)
			if not columns.has(column): columns[column] = []
			columns[column].append(cell.y)
	# Each same-column solid cell pair forbids exactly one lift. Search this
	# finite set rather than walking all the empty space below tall entities.
	var blocked_lifts = {}
	for source in sources:
		var copied = source.copy()
		copied.cell += Vector3i.RIGHT
		copies.append(copied)
		if not copied.resolved_properties().get("solid", true): continue
		for cell in copied.occupied_cells():
			for height in columns.get(Vector2i(cell.x, cell.z), []):
				if height >= cell.y: blocked_lifts[height - cell.y] = true
	var lift = 0
	while blocked_lifts.has(lift): lift += 1
	var result: Array[StringName] = []
	for copied in copies:
		copied.cell += Vector3i.UP * lift
		copied.entity_id = _next_id(copied.definition.definition_id)
		result.append(copied.entity_id)
		level.entities.append(copied)
	last_error = "\n".join(level.validate())
	for copied in copies: level.entities.erase(copied)
	if not last_error.is_empty(): return []
	end_stroke()
	_record()
	level.entities.append_array(copies)
	_notify()
	return result

func ground_position(id: StringName, cell: Vector3i) -> Variant:
	last_error = position_error(id, cell)
	if not last_error.is_empty():
		last_error = "Cannot snap an invalid position; move out of overlapping cells first.\n" + last_error
		return null
	var entity = find_entity(id)
	var candidate = entity.copy()
	candidate.cell = cell
	var cells = candidate.occupied_cells()
	var distance: int = 0
	var found = false
	# The first occupied cell to meet any other solid holds the entire rigid
	# shape. Compare grid columns directly instead of simulating a long fall.
	for other in level.entities:
		if other.entity_id == id or not other.resolved_properties().get("solid", true):
			continue
		for support in other.occupied_cells():
			for occupied in cells:
				if support.x != occupied.x or support.z != occupied.z or support.y >= occupied.y:
					continue
				var gap = occupied.y - support.y - 1
				if not found or gap < distance:
					distance = gap
					found = true
	if not found:
		last_error = "No supporting surface below the selected entity."
		return null
	var target = cell + Vector3i.DOWN * distance
	last_error = position_error(id, target)
	return target if last_error.is_empty() else null

func edit_entity(id: StringName, cell: Vector3i, turns: int, mirrored: bool, overrides: Dictionary) -> bool:
	var entity = find_entity(id)
	if not entity:
		return false
	var original = entity.copy()
	entity.cell = cell
	entity.quarter_turns = posmod(turns, 4)
	entity.mirrored = mirrored
	entity.overrides = overrides.duplicate(true)
	var errors = level.validate()
	entity.cell = original.cell
	entity.quarter_turns = original.quarter_turns
	entity.mirrored = original.mirrored
	entity.overrides = original.overrides
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return false
	_record()
	entity.cell = cell
	entity.quarter_turns = posmod(turns, 4)
	entity.mirrored = mirrored
	entity.overrides = overrides.duplicate(true)
	_notify()
	return true

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
			entity.quarter_turns = posmod(-entity.quarter_turns, 4)
			entity.mirrored = not entity.mirrored
		else:
			entity.quarter_turns = posmod(entity.quarter_turns + 1, 4)
	_notify()

func fill_floor(definition: GGEntityDefinition, origin: Vector3i, width: int, depth: int) -> void:
	begin_stroke()
	var occupied = {}
	for entity in level.entities:
		if entity.resolved_properties().get("solid", true):
			for cell in entity.occupied_cells():
				occupied[cell] = true
	for x in width:
		for z in depth:
			var cell = origin + Vector3i(x, 0, z)
			if not occupied.has(cell):
				paint(definition, cell)
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
	var errors = level.validate()
	if not errors.is_empty():
		last_error = "\n".join(errors)
		return ERR_INVALID_DATA
	# Save live external configuration, including definitions and nested game
	# rules. Built-in resources are serialized by their containing resource.
	var resources = {}
	_collect_configuration(level, {}, resources)
	for external_path in resources:
		if resources[external_path] == level:
			continue
		var configuration_error = ResourceSaver.save(resources[external_path], external_path)
		if configuration_error != OK:
			last_error = "Could not save referenced configuration: " + external_path
			return configuration_error
	var temporary = path.get_basename() + ".saving.tres"
	var error = ResourceSaver.save(level, temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error == OK:
		level.take_over_path(path)
		dirty = false
		last_error = ""
		changed.emit()
	else:
		last_error = "Could not save %s (error %d)." % [path, error]
	return error
