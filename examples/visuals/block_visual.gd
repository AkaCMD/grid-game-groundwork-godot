@tool
extends Node3D
## Primitive proportions and palette follow the Unity example prefabs.
## Keep the example art separate from the addon's generic visual fallback.
const CRATE_COLOR = Color(0.4433962, 0.34227517, 0.2007832, 1)

func configure_entity(definition: GGEntityDefinition, properties: Dictionary) -> void:
	for cell in definition.shape:
		var center = Vector3(cell)
		if properties.get("goal", false):
			_box(Vector3(0.98, 0.1, 0.98), center + Vector3(0, -0.44, 0), definition.color)
			for angle in [-PI / 4.0, PI / 4.0]:
				var crossbar = _box(Vector3(0.98, 0.025, 0.103), center + Vector3(0, -0.377, 0), CRATE_COLOR)
				crossbar.rotation.y = angle
		else:
			var size = 1.0 if properties.get("player", false) else 0.98
			if properties.get("crate", false) or definition.definition_id == &"crate_l" or definition.definition_id == &"crate":
				size = 0.95
			var dimensions = Vector3.ONE * size
			# Join adjacent cells so a multi-cell crate reads as one rigid body.
			for axis in [Vector3i.RIGHT, Vector3i.UP, Vector3i.BACK]:
				if definition.shape.has(cell + axis):
					dimensions += Vector3(axis) * ((1.0 - size) / 2.0)
					center += Vector3(axis) * ((1.0 - size) / 4.0)
				if definition.shape.has(cell - axis):
					dimensions += Vector3(axis) * ((1.0 - size) / 2.0)
					center -= Vector3(axis) * ((1.0 - size) / 4.0)
			_box(dimensions, center, definition.color)

func _box(size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var visual = GGBoardView.mesh_node(mesh, color, position)
	add_child(visual)
	return visual
