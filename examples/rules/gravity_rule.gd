@tool
class_name GGGravityRule
extends GGGameRule

@export var initial_gravity: Vector3i = Vector3i.DOWN
@export var bounds_min: Vector3i = Vector3i(-1, -1, -1)
@export var bounds_max: Vector3i = Vector3i(3, 3, 3)

func initial_state(level: GGLevel) -> Dictionary:
	var state = super.initial_state(level)
	state.gravity_direction = initial_gravity if level.gravity_enabled else Vector3i.ZERO
	return state

func resolve_action(session: GGSession, command: StringName, arguments: Dictionary) -> bool:
	if command == &"gravity":
		var direction: Vector3i = arguments.get("direction", Vector3i.ZERO)
		if direction != Vector3i.ZERO and not allows_direction(direction): return false
		session.mechanic_state.gravity_direction = direction
		return session.settle()
	return super.resolve_action(session, command, arguments)

func allows_direction(direction: Vector3i) -> bool:
	return absi(direction.x) + absi(direction.y) + absi(direction.z) == 1

func authored_cell_allowed(_level: GGLevel, cell: Vector3i) -> bool:
	return _inside(cell)

func authoring_gravity(_level: GGLevel) -> Vector3i:
	return initial_gravity

func is_outside(session: GGSession, entity_id: StringName, _direction: Vector3i) -> bool:
	for cell in GGGrid.cells(session.entities[entity_id]):
		if _inside(cell): return false
	return true

func _inside(cell: Vector3i) -> bool:
	return cell.x >= bounds_min.x and cell.y >= bounds_min.y and cell.z >= bounds_min.z and cell.x <= bounds_max.x and cell.y <= bounds_max.y and cell.z <= bounds_max.z
