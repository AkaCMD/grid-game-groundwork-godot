@tool
class_name GGPushRule
extends Resource
## Override allows() for game-specific push properties. Called before mutation.

func allows(session: GGSession, actor_id: StringName, moving_ids: Array, direction: Vector3i) -> bool:
	if moving_ids.size() <= 1:
		return true
	if not session.entities[actor_id].properties.get("can_push", false):
		return false
	for id in moving_ids:
		var entity: Dictionary = session.entities[id]
		if id != actor_id and not entity.properties.get("pushable", false):
			return false
		if id != actor_id and not entity.properties.get("transmits_push", true):
			for blocker in session.blockers(id, direction):
				if blocker != actor_id:
					return false
	return true
