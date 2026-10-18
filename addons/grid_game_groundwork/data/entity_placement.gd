@tool
class_name GGEntityPlacement
extends Resource

@export var entity_id: StringName
@export var definition: GGEntityDefinition
@export var cell: Vector3i
@export_range(0, 3) var quarter_turns: int = 0
@export var mirrored: bool = false
@export var overrides: Dictionary = {}

func resolved_properties() -> Dictionary:
	var result = definition.defaults() if definition else {}
	result.merge(overrides.duplicate(true), true)
	return result

func occupied_cells() -> Array[Vector3i]:
	var result: Array[Vector3i] = []
	if definition:
		for offset in definition.shape:
			result.append(cell + GGGrid.transform_cell(offset, quarter_turns, mirrored))
	return result

func copy() -> GGEntityPlacement:
	var result = GGEntityPlacement.new()
	result.entity_id = entity_id
	result.definition = definition
	result.cell = cell
	result.quarter_turns = quarter_turns
	result.mirrored = mirrored
	result.overrides = overrides.duplicate(true)
	return result
