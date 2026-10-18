@tool
class_name GGStrengthPushRule
extends GGPushRule
## Push strength belongs to the actor; weight belongs to pushed entities.

func allows(session: GGSession, actor_id: StringName, moving_ids: Array, direction: Vector3i) -> bool:
	if not super.allows(session, actor_id, moving_ids, direction):
		return false
	var weight: float = 0.0
	for id in moving_ids:
		if id != actor_id:
			weight += maxf(0.0, float(session.entities[id].properties.get("weight", 1.0)))
	return weight <= float(session.entities[actor_id].properties.get("strength", 1.0))
