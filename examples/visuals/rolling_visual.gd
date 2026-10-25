@tool
extends Node3D

func configure_entity(definition: GGEntityDefinition, properties: Dictionary) -> void:
	var normals = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
	var colors = [Color.CORAL, Color.GOLD, Color.DODGER_BLUE, Color.LIME_GREEN, Color.VIOLET, Color.WHITE]
	for cell in definition.shape:
		var cube = BoxMesh.new()
		cube.size = Vector3.ONE * 0.9
		add_child(GGBoardView.mesh_node(cube, definition.color, Vector3(cell)))
		for index in 6:
			var marker = BoxMesh.new()
			marker.size = Vector3.ONE * 0.45
			marker.size[normals[index].abs().max_axis_index()] = 0.03
			add_child(GGBoardView.mesh_node(marker, colors[index], Vector3(cell) + Vector3(normals[index]) * 0.46))
