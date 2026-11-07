@tool
extends Resource

@export var limit: int = 1

func resolve_command(session: GGSession, command: StringName, _arguments: Dictionary) -> bool:
	if command != &"increment":
		return false
	var count: int = session.get_mechanic_state(&"count", 0) + 1
	return session.set_mechanic_state(&"count", count) and count <= limit

func validate_layout(level: GGLevel) -> PackedStringArray:
	return ["This layout requires gravity to be disabled."] if level.gravity_enabled else []
