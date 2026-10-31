@tool
extends Node3D

func configure_entity(definition: GGEntityDefinition, _properties: Dictionary) -> void:
	var material = GGBoardView.material(Color(definition.color, 0.32))
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var surface = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	# Open cell frames reveal the actors through all six boundary planes.
	for cell in definition.shape:
		for axis in 3:
			var size = Vector3.ONE * 0.012
			size[axis] = 0.98
			var box = BoxMesh.new()
			box.size = size
			for first in [-0.49, 0.49]:
				for second in [-0.49, 0.49]:
					var position = Vector3(cell)
					position[(axis + 1) % 3] += first
					position[(axis + 2) % 3] += second
					surface.append_from(box, 0, Transform3D(Basis.IDENTITY, position))
	var mesh = MeshInstance3D.new()
	mesh.mesh = surface.commit()
	mesh.material_override = material
	add_child(mesh)
