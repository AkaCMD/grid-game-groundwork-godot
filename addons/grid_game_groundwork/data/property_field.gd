@tool
class_name GGPropertyField
extends Resource
## A named designer field. Reference kinds participate in validation and copying.

enum Kind { BOOLEAN, INTEGER, FLOAT, TEXT, CHOICE, ENTITY, ENTITIES, CELL }
@export var key: StringName
@export var label: String
@export var kind: Kind = Kind.BOOLEAN
@export var default_value: Variant
@export var choices: PackedStringArray = []
@export var required: bool = false

func value_or_default() -> Variant:
	if default_value != null: return default_value
	match kind:
		Kind.BOOLEAN: return false
		Kind.INTEGER: return 0
		Kind.FLOAT: return 0.0
		Kind.TEXT, Kind.ENTITY: return &""
		Kind.CHOICE: return choices[0] if not choices.is_empty() else ""
		Kind.ENTITIES: return []
		Kind.CELL: return Vector3i.ZERO
	return null

func accepts(value: Variant) -> bool:
	match kind:
		Kind.BOOLEAN: return value is bool
		Kind.INTEGER: return value is int
		Kind.FLOAT: return value is float or value is int
		Kind.TEXT, Kind.ENTITY: return value is String or value is StringName
		Kind.CHOICE: return (value is String or value is StringName) and choices.has(str(value))
		Kind.ENTITIES:
			if not value is Array: return false
			for id in value:
				if not (id is String or id is StringName): return false
			return true
		Kind.CELL: return value is Vector3i
	return false

func references(value: Variant) -> Array:
	if kind == Kind.ENTITY: return [StringName(value)] if str(value) != "" else []
	if kind == Kind.ENTITIES: return value
	return []

func remap(value: Variant, identities: Dictionary) -> Variant:
	if kind == Kind.ENTITY: return identities.get(StringName(value), value)
	if kind == Kind.ENTITIES:
		var result = []
		for id in value: result.append(identities.get(StringName(id), id))
		return result
	return value
