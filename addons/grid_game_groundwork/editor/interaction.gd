@tool
class_name GGEditorInteraction
extends RefCounted
## Owns tool transitions and invalidation before editor adapters rebuild visuals.

signal changed
signal paint_height_changed
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

func begin_pointer(origin: Vector3, direction: Vector3, height: int, entity_id: StringName, toggle: bool = false) -> void:
	stroke.begin()
	if can_move():
		selection.select(entity_id, toggle)
	elif can_erase_entities() or stroke.preview(origin, direction, height) != null:
		stroke.sample(origin, direction, height, entity_id)
	else:
		stroke.finish()

func sample_pointer(origin: Vector3, direction: Vector3, height: int, entity_id: StringName, held: bool) -> void:
	if held:
		stroke.sample(origin, direction, height, entity_id)
	else:
		stroke.finish()

func begin_move() -> bool:
	return can_move() and not is_drawing() and selection.begin_move()

func drag_move(target: Variant, held: bool) -> void:
	if not held:
		cancel_move()
	elif target != null:
		selection.preview_move(target)

func release_pointer(target: Variant = null) -> bool:
	if selection.is_moving():
		drag_move(target, true)
		return selection.finish_move(true)
	stroke.finish()
	return false

func pointer_exited() -> void:
	if not selection.is_moving():
		stroke.finish()

func height_target(camera_gesture: bool = false) -> HeightTarget:
	if is_drawing(): return HeightTarget.IGNORE
	if camera_gesture: return HeightTarget.CAMERA
	if stroke.can_adjust_height(): return HeightTarget.PAINT
	if can_move() and not selection.ids().is_empty(): return HeightTarget.SELECTION
	return HeightTarget.CAMERA

func handle_height(offset: int, camera_gesture: bool, apply_edit: bool) -> bool:
	match height_target(camera_gesture):
		HeightTarget.PAINT:
			if apply_edit and stroke.adjust_height(offset):
				paint_height_changed.emit()
		HeightTarget.SELECTION:
			if apply_edit:
				selection.translate(Vector3i(0, offset, 0))
		HeightTarget.CAMERA:
			return false
	return true

func set_plane(normal: Vector3i) -> void:
	cancel_move()
	stroke.set_plane(normal)
	changed.emit()

func cancel_move() -> void:
	selection.finish_move(false)

func cancel() -> void:
	cancel_move()
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
