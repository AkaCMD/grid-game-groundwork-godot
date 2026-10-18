@tool
class_name GGGrid
extends RefCounted

static func transform_cell(cell: Vector3i, turns: int, mirror: bool = false) -> Vector3i:
	var result = cell
	if mirror:
		result.x = -result.x
	for i in posmod(turns, 4):
		result = Vector3i(-result.z, result.y, result.x)
	return result

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
