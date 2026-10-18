@tool
extends Node3D
## Example-owned presentation. The addon supplies configuration and state.
var _color: Color
var _materials: Array[StandardMaterial3D] = []

func configure_entity(definition: GGEntityDefinition, properties: Dictionary) -> void:
	_color = definition.color
	for cell in definition.shape:
		var core = SphereMesh.new()
		core.radius = 0.23
		core.height = 0.46
		_add_mesh(core, Vector3(cell))
		for port in properties.get("ports", []):
			var tube = CylinderMesh.new()
			tube.top_radius = 0.18
			tube.bottom_radius = 0.18
			tube.height = 0.55
			var arm = _add_mesh(tube, Vector3(cell) + Vector3(port) * 0.25)
			if port.x != 0:
				arm.rotation.z = PI / 2.0
			elif port.z != 0:
				arm.rotation.x = PI / 2.0

func _add_mesh(mesh: Mesh, position: Vector3) -> MeshInstance3D:
	var visual = GGBoardView.mesh_node(mesh, _color, position)
	_materials.append(visual.material_override)
	add_child(visual)
	return visual

func apply_entity_state(state: Dictionary) -> void:
	var color = Color("4ce6df") if state.get("powered", false) else _color
	for material in _materials:
		material.albedo_color = color
