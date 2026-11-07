extends RefCounted
## Orders game commands and history around one active presentation.

signal presentation_requested(stages: Array[Dictionary])
signal presentation_accelerated

enum History { NONE, UNDO, REDO, RESTART }
const INPUT_BUFFER_LIMIT = 4

var _moves: Array[Vector3i] = []
var _pending_history := History.NONE
var _animating := false
var _accelerated := false

func is_animating() -> bool:
	return _animating

func is_accelerated() -> bool:
	return _accelerated

func submit_command(session: GGSession, command: StringName, arguments: Dictionary) -> Dictionary:
	if _animating:
		return {"code": &"busy", "errors": PackedStringArray()}
	return _run_command(session, command, arguments, false)

func request_move(session: GGSession, direction: Vector3i, echo: bool) -> void:
	if session.status != &"playing":
		return
	if not _animating:
		_run_move(session, direction, false)
	elif not echo and _pending_history == History.NONE and _moves.size() < INPUT_BUFFER_LIMIT:
		_moves.append(direction)
		_accelerated = true
		presentation_accelerated.emit()

func request_history(session: GGSession, action: History) -> bool:
	if action == History.NONE or session.is_resolving():
		return false
	_moves.clear()
	if _animating:
		_pending_history = action
		return true
	return _run_history(session, action)

func select_actor(session: GGSession, entity_id: StringName) -> bool:
	if _animating or not session.select_actor(entity_id):
		return false
	_moves.clear()
	return true

func finish_presentation(session: GGSession, attached: bool) -> void:
	_animating = false
	_accelerated = false
	if not attached or session.status != &"playing":
		_moves.clear()
	var action := _pending_history
	_pending_history = History.NONE
	if not attached:
		return
	if action != History.NONE:
		_run_history(session, action)
		return
	while not _moves.is_empty():
		if _run_move(session, _moves.pop_front(), true):
			return

func _run_move(session: GGSession, direction: Vector3i, accelerated: bool) -> bool:
	var arguments = {"actor_id": session.player_id(), "direction": direction}
	return _run_command(session, &"move", arguments, accelerated).code == &"accepted"

func _run_command(session: GGSession, command: StringName, arguments: Dictionary, accelerated: bool) -> Dictionary:
	var result = session.act_with_result(command, arguments)
	if result.code == &"accepted":
		_present(session, accelerated)
	return result

func _run_history(session: GGSession, action: History) -> bool:
	match action:
		History.UNDO:
			if not session.undo():
				return false
		History.REDO:
			if not session.redo():
				return false
		History.RESTART:
			session.restart()
		_:
			return false
	_present(session, false)
	return true

func _present(session: GGSession, accelerated: bool) -> void:
	_animating = true
	_accelerated = accelerated
	presentation_requested.emit(session.stages)
