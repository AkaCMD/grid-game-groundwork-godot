@tool
extends Node3D
## Square bodies and broad end collars follow Pipe/OutletStart/OutletEnd.
## Ports retain the current example's cell footprint and orientation.
const WATER_COLOR = Color(0, 0.27355617, 0.5849056, 1)
var _water: Array[MeshInstance3D] = []

func configure_entity(definition: GGEntityDefinition, properties: Dictionary) -> void:
	for cell in definition.shape:
		var center = Vector3(cell)
		_box(Vector3.ONE * 0.6, center, definition.color)
		for port in properties.get("ports", []):
			var direction = Vector3(port).normalized()
			# Build along X first; rotate to any authored port, including vertical.
			var basis = Basis(Quaternion(Vector3.RIGHT, direction))
			var collar = _box(Vector3(0.25, 0.8, 1.0), center + direction * 0.35, definition.color)
			collar.basis = basis
			var opening = _box(Vector3(0.012, 0.5, 0.5), center + direction * 0.481, definition.color.darkened(0.75))
			opening.basis = basis
			var water = _box(Vector3(0.014, 0.38, 0.38), center + direction * 0.49, WATER_COLOR)
			water.basis = basis
			water.visible = false
			_water.append(water)
		# A narrow surface channel keeps flow visible from the high camera.
		for port in properties.get("ports", []):
			var direction = Vector3(port).normalized()
			if direction.y != 0:
				continue
			var size = Vector3(0.6, 0.012, 0.16) if direction.x != 0 else Vector3(0.16, 0.012, 0.6)
			var water = _box(size, center + direction * 0.15 + Vector3(0, 0.307, 0), WATER_COLOR)
			water.visible = false
			_water.append(water)

func _box(size: Vector3, position: Vector3, color: Color) -> MeshInstance3D:
	var mesh = BoxMesh.new()
	mesh.size = size
	var visual = GGBoardView.mesh_node(mesh, color, position)
	add_child(visual)
	return visual

func apply_entity_state(state: Dictionary) -> void:
	for water in _water:
		water.visible = state.get("powered", false)
