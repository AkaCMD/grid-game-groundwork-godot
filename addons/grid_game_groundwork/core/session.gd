class_name GGSession
extends RefCounted
## Public simulation boundary. No scene-tree or physics dependencies.

const STATE_VALUE_TYPES = [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_STRING_NAME, TYPE_VECTOR3I]

var entities: Dictionary = {}
var mechanic_state: Dictionary = {}
var status: StringName = &"playing"
var stages: Array[Dictionary] = []
var initial_entities: Dictionary = {}
# Selection is UI state and deliberately excluded from action snapshots.
var selected_actor: StringName = &""
var _level: GGLevel
var _rule: GGGameRule
var _initial: Dictionary
var _history: Array[Dictionary] = []
var _future: Array[Dictionary] = []
var _resolving = false
var _resolution_failed = false
var _fall_steps = 0
var _settling = false

func start(level: GGLevel) -> PackedStringArray:
	if _resolving:
		return PackedStringArray(["Cannot start a level during action resolution."])
	var errors = level.validate()
	if not errors.is_empty():
		return errors
	_level = level
	_rule = level.rule()
	selected_actor = &""
	entities.clear()
	mechanic_state = _rule.initial_state(level).duplicate(true)
	status = &"playing"
	_history.clear()
	_future.clear()
	stages.clear()
	for placement in level.entities:
		entities[placement.entity_id] = {
			"cell": placement.cell, "turns": placement.quarter_turns,
			"mirror": placement.mirrored, "shape": placement.definition.shape.duplicate(),
			"properties": placement.resolved_properties(), "state": {},
		}
	initial_entities = entities.duplicate(true)
	_resolution_failed = false
	_fall_steps = 0
	_resolving = true
	_rule.after_step(self)
	_settle()
	_rule.after_action(self)
	_resolving = false
	if _resolution_failed:
		_rule = null
		return PackedStringArray(["Initial resolution did not terminate."])
	_initial = snapshot()
	stages.clear()
	return errors

func snapshot() -> Dictionary:
	return {"entities": entities.duplicate(true), "mechanic_state": mechanic_state.duplicate(true), "status": status}

func entities_at(cell: Vector3i) -> Array[StringName]:
	var ids: Array[StringName] = []
	for id in entities:
		if cell in GGGrid.cells(entities[id]):
			ids.append(id)
	return ids

func has_entity(entity_id: StringName) -> bool:
	return entities.has(entity_id)

func get_entity_cells(entity_id: StringName) -> Array[Vector3i]:
	return GGGrid.cells(entities[entity_id]) if has_entity(entity_id) else []

func get_entity_property(entity_id: StringName, key: StringName, fallback: Variant = null) -> Variant:
	if not has_entity(entity_id):
		return _copy_value(fallback)
	return _copy_value(entities[entity_id].properties.get(key, fallback))

func get_entity_state(entity_id: StringName, key: StringName, fallback: Variant = null) -> Variant:
	if not has_entity(entity_id):
		return _copy_value(fallback)
	return _copy_value(entities[entity_id].state.get(key, fallback))

func set_entity_state(entity_id: StringName, key: StringName, value: Variant) -> bool:
	if not _resolving or not has_entity(entity_id) or typeof(value) not in STATE_VALUE_TYPES:
		return false
	entities[entity_id].state[key] = value
	return true

func set_outcome(outcome: StringName) -> bool:
	if not _resolving or outcome not in [&"won", &"failed"]:
		return false
	status = outcome
	return true

func get_mechanic_state(key: StringName, fallback: Variant = null) -> Variant:
	return _copy_value(mechanic_state.get(key, fallback))

func set_mechanic_state(key: StringName, value: Variant) -> bool:
	## Scalar mechanic state can only be updated inside the current resolution.
	if not _resolving or typeof(value) not in STATE_VALUE_TYPES:
		return false
	mechanic_state[key] = value
	return true

func _copy_value(value: Variant) -> Variant:
	if value is Array or value is Dictionary:
		return value.duplicate(true)
	return value

func restore(state: Dictionary) -> void:
	entities = state.entities.duplicate(true)
	mechanic_state = state.mechanic_state.duplicate(true)
	status = state.status

func blockers(entity_id: StringName, direction: Vector3i) -> Array:
	var occupied = GGGrid.index(entities)
	var result = []
	for cell in GGGrid.cells(entities[entity_id]):
		for id in occupied.get(cell + direction, []):
			if id != entity_id and not result.has(id) and _rule.blocks_entity(self, entity_id, id, direction):
				result.append(id)
	return result

func move(actor_id: StringName, direction: Vector3i) -> bool:
	return act(&"move", {"actor_id": actor_id, "direction": direction})

func act(command: StringName, arguments: Dictionary = {}) -> bool:
	return act_with_result(command, arguments).code == &"accepted"

func is_resolving() -> bool:
	return _resolving

func act_with_result(command: StringName, arguments: Dictionary = {}) -> Dictionary:
	if not _rule or _resolving or status != &"playing":
		return {"code": &"unavailable", "errors": PackedStringArray()}
	var before = snapshot()
	var previous_stages = stages
	stages = []
	_resolution_failed = false
	_fall_steps = 0
	_resolving = true
	var accepted = _rule.resolve_action(self, command, arguments)
	if accepted and not _resolution_failed:
		_rule.after_action(self)
	var errors = PackedStringArray()
	if accepted and not _resolution_failed:
		errors = _rule.validate_state(self)
	_resolving = false
	var code: StringName = &"accepted"
	if _resolution_failed:
		code = &"resolution_failed"
		errors = PackedStringArray(["Action resolution did not complete."])
	elif not accepted:
		code = &"rejected"
	elif not errors.is_empty():
		code = &"invalid_state"
	if code != &"accepted":
		restore(before)
		stages = previous_stages
	else:
		_history.append(before)
		_future.clear()
		stages.append(snapshot())
	return {"code": code, "errors": errors}

func step(actor_id: StringName, direction: Vector3i) -> bool:
	## Resolver primitive: one grid step and gravity, without creating history.
	if status != &"playing" or not entities.has(actor_id):
		return false
	if not _resolving or absi(direction.x) + absi(direction.y) + absi(direction.z) != 1:
		return false
	var moving = {}
	if not _plan(actor_id, direction, moving):
		return false
	if not _rule.allows_push(self, actor_id, moving.keys(), direction):
		return false
	var carried = _rule.carried_entities(self, actor_id, direction)
	for id in carried:
		if not entities.has(id) or not entities[id].properties.get("movable", false):
			return false
		moving[id] = true
	for id in carried:
		for blocker in blockers(id, direction):
			if not moving.has(blocker):
				return false
	for id in moving:
		entities[id].cell += direction
	stages.append(snapshot())
	_rule.after_step(self)
	return _settle()

func _plan(id: StringName, direction: Vector3i, moving: Dictionary) -> bool:
	if moving.has(id):
		return true
	if not entities[id].properties.get("movable", false):
		return false
	moving[id] = true
	if not entities[id].properties.get("solid", true):
		return true
	for blocker in blockers(id, direction):
		if not _plan(blocker, direction, moving):
			return false
	return true

func settle() -> bool:
	if not _resolving: return false
	return _settle()

func _settle() -> bool:
	if _settling:
		_resolution_failed = true
		return false
	_settling = true
	var accepted = _rule.resolve_gravity(self)
	_settling = false
	if not accepted: _resolution_failed = true
	return accepted

func fall(direction: Vector3i) -> bool:
	if not _resolving: return false
	if direction == Vector3i.ZERO: return true
	if absi(direction.x) + absi(direction.y) + absi(direction.z) != 1:
		_resolution_failed = true
		return false
	while true:
		var falling = {}
		for id in entities:
			var properties: Dictionary = entities[id].properties
			if properties.get("movable", false) and properties.get("gravity", true): falling[id] = true
		var occupied = GGGrid.index(entities)
		var changed = true
		while changed:
			changed = false
			for id in falling.keys():
				for cell in GGGrid.cells(entities[id]):
					for support in occupied.get(cell + direction, []):
						if support != id and not falling.has(support) and _rule.supports_entity(self, id, support, direction):
							falling.erase(id)
							changed = true
							break
					if not falling.has(id): break
		if falling.is_empty(): return true
		_fall_steps += 1
		if _fall_steps > _rule.resolution_limit:
			_resolution_failed = true
			return false
		for id in falling: entities[id].cell += direction
		for id in falling:
			if entities.has(id) and _rule.is_outside(self, id, direction): _rule.on_fall_out(self, id)
		stages.append(snapshot())
		_rule.after_step(self)
		var next_direction = _rule.gravity_direction(self)
		if next_direction == Vector3i.ZERO: return true
		if absi(next_direction.x) + absi(next_direction.y) + absi(next_direction.z) != 1:
			_resolution_failed = true
			return false
		direction = next_direction
	return true

func is_clear(entity_id: StringName, cells: Array[Vector3i]) -> bool:
	var occupied = GGGrid.index(entities)
	for cell in cells:
		for other in occupied.get(cell, []):
			if other != entity_id and _rule.blocks_entity(self, entity_id, other, Vector3i.ZERO): return false
	return true

func _begin_action() -> void:
	_history.append(snapshot())
	_future.clear()
	stages.clear()

func undo() -> bool:
	if _resolving: return false
	if _history.is_empty():
		return false
	_future.append(snapshot())
	restore(_history.pop_back())
	stages = [snapshot()]
	return true

func redo() -> bool:
	if _resolving: return false
	if _future.is_empty():
		return false
	_history.append(snapshot())
	restore(_future.pop_back())
	stages = [snapshot()]
	return true

func restart() -> void:
	if _resolving or not _rule: return
	_begin_action()
	restore(_initial)
	stages = [snapshot()]

func select_actor(entity_id: StringName) -> bool:
	if not entities.has(entity_id) or not entities[entity_id].properties.get("player", false):
		return false
	selected_actor = entity_id
	return true

func player_id() -> StringName:
	if entities.has(selected_actor) and entities[selected_actor].properties.get("player", false):
		return selected_actor
	for id in entities:
		if entities[id].properties.get("player", false):
			return id
	return &""
