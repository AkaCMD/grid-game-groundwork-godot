@tool
class_name GGQuackRule
extends GGGameRule
## Ducks never push. Bread is passable only to a hungry duck, ending its slide.

func allows_push(_session: GGSession, _actor_id: StringName, moving_ids: Array, _direction: Vector3i) -> bool:
	return moving_ids.size() == 1

func resolve_move(session: GGSession, actor_id: StringName, direction: Vector3i) -> bool:
	if not session.entities[actor_id].properties.get("player", false):
		return false
	# A straight slide cannot cross more than the authored board's span before
	# falling out. Reject unbounded slides in edited, gravity-disabled levels.
	var minimum = session.entities[actor_id].cell
	var maximum = minimum
	for entity in session.initial_entities.values():
		for cell in GGGrid.cells(entity):
			minimum = minimum.min(cell)
			maximum = maximum.max(cell)
	var limit = maxi(maximum.x - minimum.x, maximum.z - minimum.z) + 2
	var moved = false
	for _step in range(limit):
		var was_fed: bool = session.entities[actor_id].state.get("fed", false)
		if not session.step(actor_id, direction):
			return moved
		moved = true
		if session.status == &"failed" or not session.entities.has(actor_id):
			return true
		if not was_fed and session.entities[actor_id].state.get("fed", false):
			return true
	return false

func blocks_entity(session: GGSession, actor_id: StringName, obstacle_id: StringName, direction: Vector3i) -> bool:
	if super.blocks_entity(session, actor_id, obstacle_id, direction):
		return true
	return session.entities[obstacle_id].properties.get("bread", false) and session.entities[actor_id].state.get("fed", false)

func after_step(session: GGSession) -> void:
	var occupied = GGGrid.index(session.entities)
	for duck in session.entities.values():
		if not duck.properties.get("player", false) or duck.state.get("fed", false):
			continue
		for cell in GGGrid.cells(duck):
			for id in occupied.get(cell, []):
				if session.entities.has(id) and session.entities[id].properties.get("bread", false) and not duck.state.get("fed", false):
					session.entities.erase(id)
					duck.state["fed"] = true
					session.stages.append(session.snapshot())

func after_action(session: GGSession) -> void:
	if session.status == &"failed":
		return
	for entity in session.entities.values():
		if entity.properties.get("bread", false):
			return
	session.status = &"won"
