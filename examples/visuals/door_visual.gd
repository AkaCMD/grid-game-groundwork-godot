@tool
extends Node3D
var _mesh: MeshInstance3D

func configure_entity(definition: GGEntityDefinition, _properties: Dictionary) -> void:
	var box = BoxMesh.new()
	box.size = Vector3(0.95, 1.0, 0.95)
	_mesh = GGBoardView.mesh_node(box, definition.color)
	add_child(_mesh)

func apply_entity_state(state: Dictionary) -> void:
	if _mesh:
		_mesh.scale.y = 0.08 if state.get("open", false) else 1.0
		_mesh.position.y = -0.43 if state.get("open", false) else 0.0
