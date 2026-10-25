@tool
class_name GGRollingRule
extends GGGameRule

@export var winning_up: Vector3i = Vector3i.DOWN

func resolve_move(session: GGSession, actor_id: StringName, direction: Vector3i) -> bool:
	if not allows_direction(direction): return false
	var entity: Dictionary = session.entities[actor_id]
	var cells = GGGrid.cells(entity)
	var edge = -INF
	var bottom = INF
	for cell in cells:
		edge = maxf(edge, Vector3(cell).dot(Vector3(direction)))
		bottom = minf(bottom, cell.y)
	var pivot = Vector3(direction) * (edge + 0.5) + Vector3.UP * (bottom - 0.5)
	var axis = Vector3i(Vector3(direction).cross(Vector3.UP))
	var rotation = Basis(Vector3(axis), -PI / 2.0)
	entity.cell = Vector3i((pivot + rotation * (Vector3(entity.cell) - pivot)).round())
	entity.turns = GGGrid.rotated(entity.turns, axis)
	if not session.is_clear(actor_id, GGGrid.cells(entity)): return false
	session.stages.append(session.snapshot())
	after_step(session)
	return session.settle()

func after_action(session: GGSession) -> void:
	if session.status != &"playing": return
	var actor = session.player_id()
	if actor == &"": return
	var entity: Dictionary = session.entities[actor]
	if GGGrid.transform_cell(Vector3i.UP, entity.turns) != winning_up: return
	var cells = GGGrid.cells(entity)
	for other in session.entities.values():
		if other.properties.get("goal", false) and cells.has(other.cell): session.status = &"won"
