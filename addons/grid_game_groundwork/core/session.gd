class_name GGSession
extends RefCounted
## Public simulation boundary. No scene-tree or physics dependencies.

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

func start(level: GGLevel) -> PackedStringArray:
	var errors = level.validate()
	if not errors.is_empty():
		return errors
	_level = level
	_rule = level.game_rule if level.game_rule else GGGameRule.new()
	selected_actor = &""
	entities.clear()
	mechanic_state.clear()
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
	_rule.after_step(self)
	_settle()
	_rule.after_action(self)
	_initial = snapshot()
	stages.clear()
	return errors

func snapshot() -> Dictionary:
	return {"entities": entities.duplicate(true), "mechanic_state": mechanic_state.duplicate(true), "status": status}

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
	if status != &"playing" or not entities.has(actor_id):
		return false
	if direction.y != 0 or absi(direction.x) + absi(direction.z) != 1:
		return false
	var before = snapshot()
	var previous_stages = stages
	stages = []
	if not _rule.resolve_move(self, actor_id, direction):
		restore(before)
		stages = previous_stages
		return false
	_history.append(before)
	_future.clear()
	_rule.after_action(self)
	stages.append(snapshot())
	return true

func step(actor_id: StringName, direction: Vector3i) -> bool:
	## Resolver primitive: one grid step and gravity, without creating history.
	if status != &"playing" or not entities.has(actor_id):
		return false
	if direction.y != 0 or absi(direction.x) + absi(direction.z) != 1:
		return false
	var moving = {}
	if not _plan(actor_id, direction, moving):
		return false
	if not _rule.allows_push(self, actor_id, moving.keys(), direction):
		return false
	for id in moving:
		entities[id].cell += direction
	stages.append(snapshot())
	_rule.after_step(self)
	_settle()
	return true

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

func _settle() -> void:
	if not _level.gravity_enabled:
		return
	# A simultaneous falling set handles stacks and mutually interlocked shapes.
	# Remove entities supported by something outside that set until it stabilizes.
	while true:
		var falling = {}
		for id in entities:
			var properties: Dictionary = entities[id].properties
			if properties.get("movable", false) and properties.get("gravity", true):
				falling[id] = true
		var changed = true
		while changed:
			changed = false
			for id in falling.keys():
				for support in blockers(id, Vector3i.DOWN):
					if not falling.has(support):
						falling.erase(id)
						changed = true
						break
		if falling.is_empty():
			break
		for id in falling:
			entities[id].cell += Vector3i.DOWN
			var highest = _level.void_height
			for cell in GGGrid.cells(entities[id]):
				highest = maxi(highest, cell.y)
			if highest <= _level.void_height:
				if entities[id].properties.get("player", false):
					status = &"failed"
				entities.erase(id)
		stages.append(snapshot())
		_rule.after_step(self)

func _begin_action() -> void:
	_history.append(snapshot())
	_future.clear()
	stages.clear()

func undo() -> bool:
	if _history.is_empty():
		return false
	_future.append(snapshot())
	restore(_history.pop_back())
	stages = [snapshot()]
	return true

func redo() -> bool:
	if _future.is_empty():
		return false
	_history.append(snapshot())
	restore(_future.pop_back())
	stages = [snapshot()]
	return true

func restart() -> void:
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
