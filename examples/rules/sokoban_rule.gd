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
	var covered = {}
	for entity in session.entities.values():
		if not entity.properties.get("crate", false):
			continue
		for cell in GGGrid.cells(entity):
			if goals.has(cell):
				covered[cell] = true
	var solved = not goals.is_empty() and covered.size() == goals.size()
	session.mechanic_state["crates_on_goals"] = solved
	session.status = &"won" if solved else &"playing"
