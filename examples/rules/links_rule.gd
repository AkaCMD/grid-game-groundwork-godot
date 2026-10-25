@tool
class_name GGLinksRule
extends GGGameRule

func blocks_entity(session: GGSession, actor_id: StringName, obstacle_id: StringName, direction: Vector3i) -> bool:
	var actor: Dictionary = session.entities[actor_id]
	if actor.properties.get("door", false) and actor.state.get("open", false): return false
	var obstacle: Dictionary = session.entities[obstacle_id]
	if obstacle.properties.get("door", false) and obstacle.state.get("open", false): return false
	return super.blocks_entity(session, actor_id, obstacle_id, direction)

func after_step(session: GGSession) -> void:
	_update_doors(session)
	var occupied = GGGrid.index(session.entities)
	for actor_id in session.entities.keys():
		var actor: Dictionary = session.entities[actor_id]
		if not actor.properties.get("movable", false): continue
		var portals = []
		for cell in GGGrid.cells(actor):
			for id in occupied.get(cell, []):
				if session.entities[id].properties.get("portal", false): portals.append(id)
		if not portals.has(actor.state.get("portal_latch", &"")): actor.state.erase("portal_latch")
		for portal_id in portals:
			if actor.state.get("portal_latch", &"") == portal_id: continue
			var destination = StringName(session.entities[portal_id].properties.get("target", &""))
			if not session.entities.has(destination): continue
			var target: Vector3i = session.entities[destination].cell
			var candidate = actor.duplicate(true)
			candidate.cell = target
			if not session.is_clear(actor_id, GGGrid.cells(candidate)): continue
			actor.cell = target
			actor.state["portal_latch"] = destination
			session.stages.append(session.snapshot())
			break
	_update_doors(session)

func _update_doors(session: GGSession) -> void:
	var occupied = GGGrid.index(session.entities)
	for entity in session.entities.values():
		if entity.properties.get("door", false): entity.state["open"] = false
	for entity in session.entities.values():
		if not entity.properties.get("switch", false): continue
		var active = false
		for cell in GGGrid.cells(entity):
			for id in occupied.get(cell, []):
				if session.entities[id].properties.get("movable", false): active = true
		entity.state["active"] = active
		if active:
			for id in entity.properties.get("doors", []):
				if session.entities.has(StringName(id)): session.entities[StringName(id)].state["open"] = true

func after_action(session: GGSession) -> void:
	if session.status != &"playing": return
	var actor_id = session.player_id()
	if actor_id == &"": return
	var cells = GGGrid.cells(session.entities[actor_id])
	for entity in session.entities.values():
		if entity.properties.get("goal", false) and cells.has(entity.cell): session.status = &"won"
