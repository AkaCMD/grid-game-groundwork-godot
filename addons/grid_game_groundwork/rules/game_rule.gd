@tool
class_name GGGameRule
extends Resource
## Configuration only: store mutable mechanics in session.mechanic_state or entity.state.
## Those dictionaries participate in undo/redo; fields on this resource do not.

@export var push_rule: GGPushRule
@export_range(1, 65536) var resolution_limit: int = 4096

func allows_push(session: GGSession, actor_id: StringName, moving_ids: Array, direction: Vector3i) -> bool:
	var policy = push_rule if push_rule else GGPushRule.new()
	return policy.allows(session, actor_id, moving_ids, direction)

func after_action(_session: GGSession) -> void:
	pass

func resolve_move(session: GGSession, actor_id: StringName, direction: Vector3i) -> bool:
	## Override to compose multiple steps into one complete action.
	return session.step(actor_id, direction)

func carried_entities(_session: GGSession, _actor_id: StringName, _direction: Vector3i) -> Array:
	## Optional companions moved simultaneously, without pushing their obstacles.
	## Recomputed each step; the game decides which companions to leave behind.
	return []

func blocks_entity(session: GGSession, _actor_id: StringName, obstacle_id: StringName, _direction: Vector3i) -> bool:
	## Used for both horizontal collision and support during gravity.
	return session.entities[obstacle_id].properties.get("solid", true)

func after_step(_session: GGSession) -> void:
	## Interaction phase after each grid displacement, including falling.
	pass

func validate_level(level: GGLevel) -> PackedStringArray:
	var errors = PackedStringArray()
	var occupied = {}
	for entity in level.entities:
		for cell in entity.occupied_cells():
			if not authored_cell_allowed(level, cell):
				errors.append("%s starts at or below the fall-out height or outside the activity bounds." % entity.entity_id)
			for other in occupied.get(cell, []):
				if blocks_placement(level, entity, other):
					errors.append("Solid entities %s and %s overlap at %s." % [other.entity_id, entity.entity_id, cell])
			if not occupied.has(cell): occupied[cell] = []
			occupied[cell].append(entity)
	return errors

func initial_state(level: GGLevel) -> Dictionary:
	return {"gravity_direction": Vector3i.DOWN if level.gravity_enabled else Vector3i.ZERO, "fall_out_height": level.void_height}

func resolve_action(session: GGSession, command: StringName, arguments: Dictionary) -> bool:
	if command != &"move": return false
	var actor: Variant = arguments.get("actor_id", &"")
	var direction: Variant = arguments.get("direction", Vector3i.ZERO)
	if not (actor is String or actor is StringName) or not direction is Vector3i: return false
	var actor_id = StringName(actor)
	if not session.entities.has(actor_id) or not allows_direction(direction): return false
	return resolve_move(session, actor_id, direction)

func allows_direction(direction: Vector3i) -> bool:
	return direction.y == 0 and absi(direction.x) + absi(direction.z) == 1

func gravity_direction(session: GGSession) -> Vector3i:
	return session.mechanic_state.get("gravity_direction", Vector3i.ZERO)

func resolve_gravity(session: GGSession) -> bool:
	return session.fall(gravity_direction(session))

func supports_entity(session: GGSession, actor_id: StringName, support_id: StringName, direction: Vector3i) -> bool:
	return blocks_entity(session, actor_id, support_id, direction)

func is_outside(session: GGSession, entity_id: StringName, direction: Vector3i) -> bool:
	var limit: int = -session.mechanic_state.get("fall_out_height", -8)
	for cell in GGGrid.cells(session.entities[entity_id]):
		if GGGrid.dot(cell, direction) < limit: return false
	return true

func on_fall_out(session: GGSession, entity_id: StringName) -> void:
	if session.entities[entity_id].properties.get("player", false): session.status = &"failed"
	session.entities.erase(entity_id)

func validate_state(session: GGSession) -> PackedStringArray:
	for id in session.entities:
		if session.entities[id].properties.get("solid", true) and not session.is_clear(id, GGGrid.cells(session.entities[id])):
			return PackedStringArray(["Resolved entities overlap: %s" % id])
	return []

func authoring_gravity(_level: GGLevel) -> Vector3i:
	return Vector3i.DOWN

func supports_placement(_level: GGLevel, _actor: GGEntityPlacement, other: GGEntityPlacement, _direction: Vector3i) -> bool:
	return other.resolved_properties().get("solid", true)

func authored_cell_allowed(level: GGLevel, cell: Vector3i) -> bool:
	return cell.y > level.void_height

func blocks_placement(_level: GGLevel, actor: GGEntityPlacement, other: GGEntityPlacement) -> bool:
	return actor.resolved_properties().get("solid", true) and other.resolved_properties().get("solid", true)
