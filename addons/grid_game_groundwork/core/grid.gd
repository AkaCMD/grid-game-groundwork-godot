@tool
class_name GGGrid
extends RefCounted

static var _orientations: Array[Basis] = []

static func orientations() -> Array[Basis]:
	if not _orientations.is_empty(): return _orientations
	var result: Array[Basis] = []
	for turns in 4:
		var x = Vector3i.RIGHT
		for i in turns: x = Vector3i(-x.z, x.y, x.x)
		result.append(Basis(Vector3(x), Vector3.UP, Vector3(x).cross(Vector3.UP)))
	for up in [Vector3.DOWN, Vector3.RIGHT, Vector3.LEFT, Vector3.BACK, Vector3.FORWARD]:
		for right in [Vector3.RIGHT, Vector3.BACK, Vector3.LEFT, Vector3.FORWARD, Vector3.UP, Vector3.DOWN]:
			if up.dot(right) == 0:
				result.append(Basis(right, up, right.cross(up)))
	_orientations = result
	return result

static func orientation_basis(index: int, mirror: bool = false) -> Basis:
	var basis = orientations()[posmod(index, 24)]
	return basis * Basis.from_scale(Vector3(-1, 1, 1)) if mirror else basis

static func orientation_index(basis: Basis) -> int:
	var values = orientations()
	for index in values.size():
		if values[index].is_equal_approx(basis): return index
	return -1

static func rotated(index: int, axis: Vector3i, turns: int = 1) -> int:
	var rotation = Basis(Vector3(axis), -turns * PI / 2.0)
	return orientation_index(rotation * orientation_basis(index))

static func transform_cell(cell: Vector3i, turns: int, mirror: bool = false) -> Vector3i:
	var basis = orientation_basis(turns, mirror)
	return Vector3i(basis.x.round()) * cell.x + Vector3i(basis.y.round()) * cell.y + Vector3i(basis.z.round()) * cell.z

static func dot(a: Vector3i, b: Vector3i) -> int:
	return a.x * b.x + a.y * b.y + a.z * b.z

static func cells(entity: Dictionary) -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	for offset in entity.shape:
		result.append(entity.cell + transform_cell(offset, entity.turns, entity.mirror))
	return result

static func index(entities: Dictionary, solid_only: bool = false) -> Dictionary:
	var result = {}
	for id in entities:
		var entity: Dictionary = entities[id]
		if solid_only and not entity.properties.get("solid", true):
			continue
		for cell in cells(entity):
			if not result.has(cell):
				result[cell] = []
			result[cell].append(id)
	return result
