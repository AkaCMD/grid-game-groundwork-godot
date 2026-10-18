@tool
class_name GGSokobanRule
extends GGGameRule

func after_action(session: GGSession) -> void:
	if session.status == &"failed":
		return
	var goals = {}
	for entity in session.entities.values():
		if entity.properties.get("goal", false):
			for cell in GGGrid.cells(entity):
				goals[cell] = true
	var crate_count = 0
	var solved = true
	for id in session.initial_entities:
		if not session.initial_entities[id].properties.get("crate", false):
			continue
		crate_count += 1
		var on_goal = false
		if session.entities.has(id):
			for cell in GGGrid.cells(session.entities[id]):
				if goals.has(cell):
					on_goal = true
		if not on_goal:
			solved = false
	session.mechanic_state["crates_on_goals"] = solved
	session.status = &"won" if solved and crate_count > 0 else &"playing"
