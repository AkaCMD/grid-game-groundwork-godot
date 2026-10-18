@tool
class_name GGPipeRule
extends GGGameRule

func after_action(session: GGSession) -> void:
	var pipes = {}
	var frontier = []
	var visited = {}
	for id in session.entities:
		var entity: Dictionary = session.entities[id]
		if entity.properties.get("pipe", false):
			pipes[entity.cell] = id
			entity.state["powered"] = false
			if entity.properties.get("source", false):
				frontier.append(id)
	while not frontier.is_empty():
		var id = frontier.pop_front()
		if visited.has(id):
			continue
		visited[id] = true
		var entity: Dictionary = session.entities[id]
		entity.state["powered"] = true
		for direction in _ports(entity):
			var neighbor_id = pipes.get(entity.cell + direction, &"")
			if neighbor_id != &"" and _ports(session.entities[neighbor_id]).has(-direction):
				frontier.append(neighbor_id)
	var destinations = 0
	var connected = true
	for id in session.initial_entities:
		if session.initial_entities[id].properties.get("destination", false):
			destinations += 1
			if not visited.has(id):
				connected = false
	session.mechanic_state["flowing_entities"] = visited.keys()
	if session.status != &"failed":
		session.status = &"won" if connected and destinations > 0 else &"playing"

func _ports(entity: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for direction in entity.properties.get("ports", []):
		result.append(GGGrid.transform_cell(Vector3i(direction), entity.turns, entity.mirror))
	return result
