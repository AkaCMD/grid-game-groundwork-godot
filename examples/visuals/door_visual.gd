@tool
extends "res://examples/visuals/block_visual.gd"

var _doors: Array[Node3D] = []

func configure_entity(definition: GGEntityDefinition, _properties: Dictionary) -> void:
	for cell in definition.shape:
		var door = Node3D.new()
		door.position = Vector3(cell) + Vector3(0, -0.49, 0)
		add_child(door)
		_doors.append(door)
		for side in [-1, 1]:
			var post = _box(Vector3(0.14, 0.98, 0.98), Vector3(side * 0.42, 0.49, 0), definition.color)
			post.reparent(door, false)
		var header = _box(Vector3(0.7, 0.14, 0.14), Vector3(0, 0.91, 0), definition.color)
		header.reparent(door, false)
		for x in [-0.24, 0.0, 0.24]:
			var slat = _box(Vector3(0.13, 0.82, 0.74), Vector3(x, 0.41, 0), CRATE_COLOR)
			slat.reparent(door, false)

func apply_entity_state(state: Dictionary) -> void:
	for door in _doors:
		door.scale.y = 0.08 if state.get("open", false) else 1.0
