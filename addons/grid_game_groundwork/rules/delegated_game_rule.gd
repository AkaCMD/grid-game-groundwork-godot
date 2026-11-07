@tool
class_name GGDelegatedGameRule
extends GGGameRule
## Adapts Godot resources written in other languages to the built-in rule.

@export var implementation: Resource

func _has_hook(method: StringName) -> bool:
	return implementation != null and implementation.has_method(method)

func resolve_action(session: GGSession, command: StringName, arguments: Dictionary) -> bool:
	if command == &"move":
		return super.resolve_action(session, command, arguments)
	if not _has_hook(&"resolve_command"):
		return false
	return _accepted(implementation.call(&"resolve_command", session, command, arguments), &"resolve_command")

func resolve_move(session: GGSession, actor_id: StringName, direction: Vector3i) -> bool:
	if not _has_hook(&"resolve_move"):
		return super.resolve_move(session, actor_id, direction)
	return _accepted(implementation.call(&"resolve_move", session, actor_id, direction), &"resolve_move")

func after_step(session: GGSession) -> void:
	if _has_hook(&"after_step"):
		implementation.call(&"after_step", session)

func after_action(session: GGSession) -> void:
	if _has_hook(&"after_action"):
		implementation.call(&"after_action", session)

func _accepted(result: Variant, method: StringName) -> bool:
	if typeof(result) != TYPE_BOOL:
		push_error("Game rule implementation must return a bool from %s." % method)
		return false
	return result

func validate_level(level: GGLevel) -> PackedStringArray:
	var errors = super.validate_level(level)
	if not implementation:
		errors.append("Assign an implementation to the delegated game rule.")
		return errors
	if _has_hook(&"validate_layout"):
		var result: Variant = implementation.call(&"validate_layout", level)
		if typeof(result) == TYPE_PACKED_STRING_ARRAY:
			errors.append_array(result)
		else:
			errors.append("Game rule implementation must return a PackedStringArray from validate_layout.")
	elif not [&"resolve_command", &"resolve_move", &"after_step", &"after_action"].any(_has_hook):
		errors.append("Game rule implementation must expose a supported hook. Check that its code is built and available in the editor.")
	return errors
