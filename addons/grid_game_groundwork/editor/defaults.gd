@tool
class_name GGDefaults
extends RefCounted

static func palette() -> Array[GGEntityDefinition]:
	var result: Array[GGEntityDefinition] = []
	for id in ["ground", "wall", "player", "crate", "goal"]:
		var definition = GGEntityDefinition.new()
		definition.definition_id = StringName(id)
		definition.display_name = id.capitalize()
		match id:
			"ground", "wall":
				definition.movable = false
				definition.affected_by_gravity = false
				definition.color = Color("465b73")
				definition.properties = {"ground": id == "ground"}
			"player":
				definition.color = Color("64d5d0")
				definition.properties = {"player": true, "can_push": true, "strength": 5.0}
			"crate":
				definition.properties = {"crate": true, "pushable": true, "transmits_push": true, "weight": 1.0}
			"goal":
				definition.solid = false
				definition.movable = false
				definition.affected_by_gravity = false
				definition.color = Color("a8ef79")
				definition.properties = {"goal": true}
		result.append(definition)
	return result
