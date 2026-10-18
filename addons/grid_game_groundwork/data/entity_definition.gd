@tool
class_name GGEntityDefinition
extends Resource
## Reusable authored defaults. A session never mutates this resource.

@export var definition_id: StringName = &"entity":
	set(value):
		definition_id = value
		emit_changed()
@export var display_name: String = "Entity":
	set(value):
		display_name = value
		emit_changed()
@export var shape: Array[Vector3i] = [Vector3i.ZERO]:
	set(value):
		shape = value
		emit_changed()
@export var solid: bool = true:
	set(value):
		solid = value
		emit_changed()
@export var movable: bool = true:
	set(value):
		movable = value
		emit_changed()
@export var affected_by_gravity: bool = true:
	set(value):
		affected_by_gravity = value
		emit_changed()
@export var color: Color = Color("e5ac58"):
	set(value):
		color = value
		emit_changed()
@export var visual_scene: PackedScene:
	set(value):
		visual_scene = value
		emit_changed()
@export var properties: Dictionary = {"pushable": true, "transmits_push": true, "weight": 1.0}:
	set(value):
		properties = value
		emit_changed()

func defaults() -> Dictionary:
	var values = properties.duplicate(true)
	values["solid"] = solid
	values["movable"] = movable
	values["gravity"] = affected_by_gravity
	return values
