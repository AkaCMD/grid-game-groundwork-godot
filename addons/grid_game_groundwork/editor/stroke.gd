@tool
class_name GGEditorStroke
extends RefCounted
## One pointer stroke: logical face fitting, stable targets and one undo group.
## Input supplies a world ray; visual meshes never determine occupied cells.

enum Mode { PAINT, ERASE, SELECT }
var _authoring: GGLevelAuthoring
var _definition: GGEntityDefinition
var _mode = Mode.PAINT
var _turns = 0
var _mirrored = false
var _shape_mode = false
var _active = false
var _surface_cells: Array[Vector3i] = []
var _visited: Dictionary = {}
var _height_offset = 0
var _manual_height = false

func _init(authoring: GGLevelAuthoring) -> void:
	_authoring = authoring
	_authoring.stroke_ended.connect(_reset)
	_authoring.level_opened.connect(reset_height)

func configure(definition: GGEntityDefinition, mode: int, turns: int = 0, mirrored: bool = false, shape_mode: bool = false) -> void:
	if definition == _definition and mode == _mode and turns == _turns and mirrored == _mirrored and shape_mode == _shape_mode:
		return
	finish()
	if definition != _definition or mode != Mode.PAINT or shape_mode:
		reset_height()
	_definition = definition
	_mode = mode
	_turns = turns
	_mirrored = mirrored
	_shape_mode = shape_mode

func is_active() -> bool:
	return _active

func can_adjust_height() -> bool:
	return _mode == Mode.PAINT and not _shape_mode and _definition != null and not _active

func height_offset() -> int:
	return _height_offset

func adjust_height(offset: int) -> bool:
	if not can_adjust_height(): return false
	_height_offset += offset
	_manual_height = true
	return true

func reset_height() -> void:
	_height_offset = 0
	_manual_height = false

func preview_error(cell: Vector3i) -> String:
	if not _manual_height or (_active and _visited.values().has(cell)): return ""
	return _authoring.placement_error(_definition, cell, _turns, _mirrored)

func begin() -> void:
	finish()
	_authoring.begin_stroke()
	_surface_cells = _occupied_cells()
	_active = true

func finish() -> void:
	if _active: _authoring.end_stroke()
	_reset()

func _reset() -> void:
	_active = false
	_surface_cells.clear()
	_visited.clear()

func preview(origin: Vector3, direction: Vector3, height: int) -> Variant:
	var cell = _cell_at(origin, direction, height)
	return _placement(cell) if cell != null else null

func sample(origin: Vector3, direction: Vector3, height: int, entity_id: StringName = &"") -> bool:
	if not _active or _mode == Mode.SELECT: return false
	if _mode == Mode.ERASE and not _shape_mode:
		if entity_id == &"" or _visited.has(entity_id): return false
		_visited[entity_id] = true
		return _authoring.erase(entity_id)
	if not _definition: return false
	var cell = _cell_at(origin, direction, height)
	if cell == null or _visited.has(cell): return false
	var target = _placement(cell)
	if target == null: return false
	if _manual_height:
		_authoring.last_error = preview_error(target)
		if not _authoring.last_error.is_empty(): return false
	_visited[cell] = target
	if _shape_mode:
		return _authoring.edit_shape(_definition, cell, _mode == Mode.ERASE)
	var painted = _authoring.paint_exact(_definition, target, _turns, _mirrored) if _manual_height else _authoring.paint(_definition, target, _turns, _mirrored)
	if not painted: _visited.erase(cell)
	return painted

func _placement(cell: Vector3i) -> Variant:
	if _mode != Mode.PAINT or _shape_mode or not _definition: return cell
	# Revisited cells retain the placement already shown/painted this stroke,
	# rather than previewing another entity stacked on the one just created.
	if _active and _visited.has(cell): return _visited[cell]
	if _manual_height: return cell + Vector3i.UP * _height_offset
	return _authoring.placement_cell(_definition, cell, _turns, _mirrored)

func _cell_at(origin: Vector3, direction: Vector3, height: int) -> Variant:
	if _mode == Mode.PAINT and not _shape_mode and _definition:
		var hit = _surface_at(origin, direction)
		if not hit.is_empty():
			var normal: Vector3i = hit.normal
			var axis = Vector3(normal).abs().max_axis_index()
			var offsets: Array[Vector3i] = []
			for cell in _definition.shape:
				offsets.append(GGGrid.transform_cell(cell, _turns, _mirrored))
			if offsets.is_empty(): return null
			var edge = offsets[0][axis]
			for offset in offsets:
				edge = mini(edge, offset[axis]) if normal[axis] > 0 else maxi(edge, offset[axis])
			var target: Vector3i = hit.cell + normal
			target[axis] -= edge
			return target
	var hit = Plane(Vector3.UP, height).intersects_ray(origin, direction)
	return Vector3i(roundi(hit.x), height, roundi(hit.z)) if hit != null else null

func _occupied_cells() -> Array[Vector3i]:
	var cells: Array[Vector3i] = []
	if _authoring.level:
		for entity in _authoring.level.entities:
			# Paint surfaces are independent of gameplay collision: non-solid
			# entities such as bread can also be stacked in the editor.
			cells.append_array(entity.occupied_cells())
	return cells

func _surface_at(origin: Vector3, direction: Vector3) -> Dictionary:
	var nearest = INF
	var result: Dictionary = {}
	var cells = _surface_cells if _active else _occupied_cells()
	for cell in cells:
		var hit = AABB(Vector3(cell) - Vector3.ONE * 0.5, Vector3.ONE).intersects_ray(origin, direction)
		if hit == null: continue
		var distance = origin.distance_squared_to(hit)
		if distance >= nearest: continue
		var local: Vector3 = hit - Vector3(cell)
		var axis = local.abs().max_axis_index()
		var normal = Vector3i.ZERO
		normal[axis] = 1 if local[axis] > 0 else -1
		nearest = distance
		result = {"cell": cell, "normal": normal}
	return result
