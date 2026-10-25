@tool
class_name GGRollingRule
extends GGGameRule

@export var winning_up: Vector3i = Vector3i.DOWN

func resolve_move(session: GGSession, actor_id: StringName, direction: Vector3i) -> bool:
	if not allows_direction(direction): return false
	var entity: Dictionary = session.entities[actor_id]
	var offsets: Array[Vector3i] = []
	for cell in entity.shape: offsets.append(GGGrid.transform_cell(cell, entity.turns, entity.mirror))
	var edge = GGGrid.dot(offsets[0], direction)
	var bottom: int = offsets[0].y
	for offset in offsets:
		edge = maxi(edge, GGGrid.dot(offset, direction))
		bottom = mini(bottom, offset.y)
	# Doubled local coordinates represent the half-cell pivot exactly.
	var pivot = direction * (edge * 2 + 1) + Vector3i.UP * (bottom * 2 - 1)
	var axis = Vector3i(Vector3(direction).cross(Vector3.UP))
	var rotation = GGGrid.rotated(0, axis)
	entity.cell += (pivot + GGGrid.transform_cell(-pivot, rotation)) / 2
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
