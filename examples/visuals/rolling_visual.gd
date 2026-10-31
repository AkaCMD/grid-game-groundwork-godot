@tool
extends "res://examples/visuals/block_visual.gd"

const GROUND = preload("res://examples/entities/ground.tres")
const GOAL = preload("res://examples/entities/goal.tres")

func configure_entity(definition: GGEntityDefinition, properties: Dictionary) -> void:
	super.configure_entity(definition, properties)
	var normals = [Vector3i.RIGHT, Vector3i.LEFT, Vector3i.UP, Vector3i.DOWN, Vector3i.BACK, Vector3i.FORWARD]
	var pips = [Vector2(-0.16, -0.16), Vector2(0.16, 0.16), Vector2(-0.16, 0.16), Vector2(0.16, -0.16), Vector2.ZERO]
	for cell in definition.shape:
		for index in normals.size():
			var normal: Vector3i = normals[index]
			if definition.shape.has(cell + normal):
				continue
			var face_basis = Basis(Quaternion(Vector3.UP, Vector3(normal)))
			var center = Vector3(cell) + Vector3(normal) * 0.51
			var target_face = normal == Vector3i.UP
			var plate = _box(Vector3(0.62, 0.02, 0.62), center, GOAL.color if target_face else GROUND.color)
			plate.basis = face_basis
			if target_face:
				# Match the goal's cross on the face that must finish pointing down.
				for angle in [-PI / 4.0, PI / 4.0]:
					var crossbar = _box(Vector3(0.62, 0.015, 0.08), center + Vector3(normal) * 0.018, CRATE_COLOR)
					crossbar.basis = face_basis * Basis(Vector3.UP, angle)
			else:
				var count = index + 1 if index < 2 else index
				for pip in pips.slice(0, count):
					var offset = face_basis * Vector3(pip.x, 0.018, pip.y)
					var dot = _box(Vector3(0.085, 0.015, 0.085), center + offset, CRATE_COLOR)
					dot.basis = face_basis
