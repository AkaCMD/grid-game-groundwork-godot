@tool
class_name GGDelegatedGameRule
extends GGGameRule
## Adapts Godot resources written in other languages to the built-in rule.

@export var implementation: Resource

func resolve_action(session: GGSession, command: StringName, arguments: Dictionary) -> bool:
	if command == &"move":
		return super.resolve_action(session, command, arguments)
	if not implementation or not implementation.has_method(&"resolve_command"):
		return false
	var result: Variant = implementation.call(&"resolve_command", session, command, arguments)
	if typeof(result) != TYPE_BOOL:
		push_error("Game rule implementation must return a bool from resolve_command.")
		return false
	return result

func validate_level(level: GGLevel) -> PackedStringArray:
	var errors = super.validate_level(level)
	if not implementation:
		errors.append("Assign an implementation to the delegated game rule.")
		return errors
	if implementation.has_method(&"validate_layout"):
		var result: Variant = implementation.call(&"validate_layout", level)
		if typeof(result) == TYPE_PACKED_STRING_ARRAY:
			errors.append_array(result)
		else:
			errors.append("Game rule implementation must return a PackedStringArray from validate_layout.")
	elif not implementation.has_method(&"resolve_command"):
		errors.append("Game rule implementation must expose resolve_command or validate_layout. Check that its code is built and available in the editor.")
	return errors
