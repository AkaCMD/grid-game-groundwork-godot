@tool
extends Node3D

func configure_entity(definition: GGEntityDefinition, _properties: Dictionary) -> void:
	var box = BoxMesh.new()
	box.size = Vector3.ONE * 0.92
	var material = GGBoardView.material(Color(definition.color, 0.12))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh = MeshInstance3D.new()
	mesh.mesh = box
	mesh.material_override = material
	add_child(mesh)
