@tool
class_name GGGameRule
extends Resource
## Configuration only: store mutable mechanics in session.mechanic_state or entity.state.
## Those dictionaries participate in undo/redo; fields on this resource do not.

@export var push_rule: GGPushRule

func allows_push(session: GGSession, actor_id: StringName, moving_ids: Array, direction: Vector3i) -> bool:
	var policy = push_rule if push_rule else GGPushRule.new()
	return policy.allows(session, actor_id, moving_ids, direction)

func after_action(_session: GGSession) -> void:
	pass

func resolve_move(session: GGSession, actor_id: StringName, direction: Vector3i) -> bool:
	## Override to compose multiple steps into one complete action.
	return session.step(actor_id, direction)
