@tool
class_name GGEditorInteraction
extends RefCounted
## Owns tool transitions and invalidation before editor adapters rebuild visuals.

signal changed
enum Mode { PAINT, ERASE, SELECT }
enum HeightTarget { CAMERA, PAINT, SELECTION, IGNORE }

var selection: GGEditorSelection
var stroke: GGEditorStroke
var mode: int:
	get: return _mode
var shape_mode: bool:
	get: return _shape_mode
var _authoring: GGLevelAuthoring
var _mode = Mode.PAINT
var _level_mode = Mode.PAINT
var _shape_mode = false
var _definition: GGEntityDefinition
var _turns = 0
var _mirrored = false

func _init(authoring: GGLevelAuthoring) -> void:
	_authoring = authoring
	selection = GGEditorSelection.new(authoring)
	stroke = GGEditorStroke.new(authoring)

func open(level: GGLevel) -> void:
	cancel()
	selection.select(&"")
	if _shape_mode: _mode = _level_mode
	_shape_mode = false
	_definition = null
	_configure_stroke()
	_authoring.open(level)
	changed.emit()

func configure_brush(definition: GGEntityDefinition, turns: int, mirrored: bool) -> void:
	if definition == _definition and turns == _turns and mirrored == _mirrored: return
	_definition = definition
	_turns = turns
	_mirrored = mirrored
	_configure_stroke()
	changed.emit()

func set_mode(value: int) -> bool:
	if value < Mode.PAINT or value > Mode.SELECT or is_drawing() or (_shape_mode and value == Mode.SELECT):
		return false
	_mode = value
	_configure_stroke()
	changed.emit()
	return true

func set_shape_mode(enabled: bool) -> bool:
	if enabled == _shape_mode: return true
	if enabled and not _definition: return false
	cancel()
	if enabled:
		_level_mode = _mode
		selection.select(&"")
		if _mode == Mode.SELECT: _mode = Mode.PAINT
	else:
		_mode = _level_mode
	_shape_mode = enabled
	_configure_stroke()
	changed.emit()
	return true

func can_move() -> bool:
	return _mode == Mode.SELECT and not _shape_mode

func can_erase_entities() -> bool:
	return _mode == Mode.ERASE and not _shape_mode

func is_drawing() -> bool:
	return stroke.is_active() or selection.is_moving()

func height_target(camera_gesture: bool = false) -> HeightTarget:
	if is_drawing(): return HeightTarget.IGNORE
	if camera_gesture: return HeightTarget.CAMERA
	if stroke.can_adjust_height(): return HeightTarget.PAINT
	if can_move() and not selection.ids().is_empty(): return HeightTarget.SELECTION
	return HeightTarget.CAMERA

func set_plane(normal: Vector3i) -> void:
	selection.finish_move(false)
	stroke.set_plane(normal)
	changed.emit()

func cancel() -> void:
	selection.finish_move(false)
	stroke.finish()

func refreshed_level() -> GGLevel:
	# Inspector edits bypass authoring.changed. Reconcile before rebuilding so
	# cached preview origins cannot overwrite externally edited placements.
	selection.reconcile()
	if not _shape_mode or not _definition: return _authoring.level
	var preview = GGLevel.new()
	var entity = GGEntityPlacement.new()
	entity.entity_id = &"shape_preview"
	entity.definition = _definition
	preview.entities.append(entity)
	return preview

func _configure_stroke() -> void:
	stroke.configure(_definition, _mode, _turns, _mirrored, _shape_mode)
