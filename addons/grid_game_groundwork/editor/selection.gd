@tool
class_name GGEditorSelection
extends RefCounted
## Editor selection and staged movement. Authoring remains the only writer of
## saved placements/history; renderers consume positions without owning a copy.

signal changed
signal preview_changed
signal feedback(message: String)
var _authoring: GGLevelAuthoring
var _level: GGLevel
var _ids: Array[StringName] = []
var _origins: Dictionary = {}
var _target: Vector3i
var _moving = false
var _error = ""

func _init(authoring: GGLevelAuthoring) -> void:
	_authoring = authoring
	_authoring.changed.connect(reconcile)
	reconcile()

func ids() -> Array[StringName]:
	return _ids.duplicate()

func active_id() -> StringName:
	return _ids.back() if not _ids.is_empty() else &""

func position() -> Vector3i:
	return _target if _moving else _origins.get(active_id(), Vector3i.ZERO)

func positions() -> Dictionary:
	var result = _origins.duplicate()
	if _moving:
		var offset = _target - _origins[active_id()]
		for id in result: result[id] += offset
	return result

func is_moving() -> bool:
	return _moving

func is_valid() -> bool:
	return _error.is_empty()

func reconcile() -> void:
	# Any authoring change invalidates an outstanding preview. Restore its
	# visuals before forgetting IDs, including deletion and switching levels.
	finish_move(false)
	if _level != _authoring.level:
		_ids.clear()
	_level = _authoring.level
	_ids = _ids.filter(func(id): return _authoring.find_entity(id) != null)
	_refresh_origins()

func _refresh_origins() -> void:
	_origins.clear()
	for id in _ids: _origins[id] = _authoring.find_entity(id).cell
	_error = ""
	changed.emit()

func select(id: StringName, toggle: bool = false) -> void:
	finish_move(false)
	if not toggle: _ids.clear()
	if toggle and _ids.has(id):
		_ids.erase(id)
	elif _authoring.level and _authoring.find_entity(id):
		_ids.append(id)
	_refresh_origins()

func begin_move() -> bool:
	if _ids.is_empty() or _moving: return false
	_target = position()
	_moving = true
	_error = ""
	return true

func preview_move(cell: Vector3i) -> void:
	if not _moving: return
	_target = cell
	_error = _authoring.translation_error(_ids, cell - _origins[active_id()])
	preview_changed.emit()
	feedback.emit("Move to %s · 1-cell snap · Esc to cancel" % cell if is_valid() else "Invalid destination: %s\nRelease to restore the original position." % _error)

func finish_move(commit: bool) -> bool:
	if not _moving: return false
	var target = _target
	var offset: Vector3i = target - _origins[active_id()]
	var accepted = commit and is_valid() and offset != Vector3i.ZERO
	_moving = false
	_error = ""
	preview_changed.emit()
	if accepted:
		if _authoring.translate_entities(_ids, offset):
			feedback.emit("Moved to %s." % target)
			return true
		feedback.emit(_authoring.last_error)
	else:
		feedback.emit("Move cancelled; original position restored.")
	return false

func translate(offset: Vector3i) -> bool:
	finish_move(false)
	var moved = _authoring.translate_entities(_ids, offset)
	feedback.emit("Moved %d selected entities by %s." % [_ids.size(), offset] if moved else _authoring.last_error)
	return moved

func snap_to_ground(rebase: Callable = Callable()) -> bool:
	# During a drag, projection may reject rebasing from the current camera
	# angle. Ask before changing the preview; headless callers need no gizmo.
	if _ids.size() != 1:
		feedback.emit("Snap down is available only for a single selected entity." if _ids.size() > 1 else "Select an entity first.")
		return false
	var origin = position()
	var target = _authoring.ground_position(active_id(), origin)
	if target == null:
		feedback.emit(_authoring.last_error)
		return false
	if target == origin:
		feedback.emit("Entity is already supported.")
		return false
	if _moving:
		if rebase.is_valid() and not rebase.call(target):
			feedback.emit("Cannot snap from this camera angle. Cancel the drag and orbit the camera.")
			return false
		preview_move(target)
		feedback.emit("Snapped to %s · Continue dragging · Esc to cancel" % target)
		return true
	var moved = _authoring.translate_entities(_ids, target - origin)
	feedback.emit("Snapped to %s." % target if moved else _authoring.last_error)
	return moved

func duplicate() -> bool:
	finish_move(false)
	var copies = _authoring.duplicate_entities(_ids)
	if copies.is_empty():
		feedback.emit(_authoring.last_error)
		return false
	_ids = copies
	_refresh_origins()
	feedback.emit("Duplicated %d entities." % copies.size())
	return true

func erase() -> bool:
	finish_move(false)
	var erased = _authoring.erase_entities(_ids)
	if not erased: feedback.emit(_authoring.last_error)
	return erased
