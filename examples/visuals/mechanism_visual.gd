@tool
extends "res://examples/visuals/block_visual.gd"

const GROUND = preload("res://examples/entities/ground.tres")
const WALL = preload("res://examples/entities/wall.tres")
var _buttons: Array[MeshInstance3D] = []

func configure_entity(definition: GGEntityDefinition, properties: Dictionary) -> void:
	for cell in definition.shape:
		var center = Vector3(cell)
		if properties.get("switch", false):
			_box(Vector3(0.98, 0.1, 0.98), center + Vector3(0, -0.44, 0), definition.color)
			var button = _box(Vector3(0.62, 0.045, 0.62), center + Vector3(0, -0.368, 0), CRATE_COLOR)
			_buttons.append(button)
		elif properties.get("portal", false):
			_box(Vector3(0.98, 0.1, 0.98), center + Vector3(0, -0.44, 0), GROUND.color)
			_box(Vector3(0.68, 0.02, 0.68), center + Vector3(0, -0.38, 0), definition.color.darkened(0.75))
			for side in [-1, 1]:
				_box(Vector3(0.1, 0.04, 0.88), center + Vector3(side * 0.39, -0.37, 0), definition.color)
				_box(Vector3(0.68, 0.04, 0.1), center + Vector3(0, -0.37, side * 0.39), definition.color)

func apply_entity_state(state: Dictionary) -> void:
	var active: bool = state.get("active", false)
	for button in _buttons:
		button.scale.y = 0.35 if active else 1.0
		button.material_override.albedo_color = WALL.color if active else CRATE_COLOR
