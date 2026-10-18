class_name GGGame
extends Node3D
## Drop this node into a scene and assign a GGLevel to play an individual level.

signal level_completed
signal level_failed
@export var level: GGLevel
@export_range(0.01, 0.5) var step_duration: float = 0.12
## Stage duration when fresh key presses are buffered during movement.
@export_range(0.01, 0.5) var buffered_step_duration: float = 0.06
const INPUT_BUFFER_LIMIT = 4
var session = GGSession.new()
var _view: GGBoardView
var _camera: Camera3D
var _camera_pivot = Vector3.ZERO
var _camera_yaw = 0.0
var _camera_pitch = deg_to_rad(75.2)
var _camera_zoom = 12.0
var _label: Label
var _busy = false
var _status: StringName
var _move_queue: Array[Vector3i] = []
var _pending_history = ""
var _active_tween: Tween
var _fast_animation = false

func _ready() -> void:
	if not level:
		push_error("Assign a level to GGGame.")
		return
	var errors = session.start(level)
	if not errors.is_empty():
		push_error("\n".join(errors))
		return
	_view = GGBoardView.new()
	add_child(_view)
	_view.configure(level)
	_view.show_state(session.snapshot())
	_build_camera()
	_build_hud()
	_update_status()

func _frame_camera() -> void:
	var bounds = AABB()
	var first = true
	for entity in level.entities:
		for cell in entity.occupied_cells():
			if first:
				bounds = AABB(Vector3(cell), Vector3.ONE)
				first = false
			else:
				bounds = bounds.expand(Vector3(cell) + Vector3.ONE).expand(Vector3(cell))
	_camera_pivot = bounds.get_center() - Vector3.ONE * 0.5
	_camera_zoom = maxf(8.0, maxf(bounds.size.x, bounds.size.z) * 1.25 + bounds.size.y * 0.5)
	_update_camera()

func _update_camera() -> void:
	_camera.size = _camera_zoom
	var distance = _camera_zoom / (2.0 * tan(deg_to_rad(_camera.fov) * 0.5))
	_camera.position = _camera_pivot + Vector3(sin(_camera_yaw) * cos(_camera_pitch), sin(_camera_pitch), cos(_camera_yaw) * cos(_camera_pitch)) * distance
	_camera.rotation = Vector3(-_camera_pitch, _camera_yaw, 0)

func _unhandled_input(event: InputEvent) -> void:
	if not _camera:
		return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			if event.pressed:
				_camera_zoom = clampf(_camera_zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 2, 100)
				_update_camera()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseMotion and event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
		if event.shift_pressed:
			_camera_pivot += (-_camera.basis.x * event.relative.x + _camera.basis.y * event.relative.y) * _camera_zoom / maxf(1.0, get_viewport().get_visible_rect().size.y)
		else:
			_camera_yaw -= event.relative.x * 0.009
			_camera_pitch = clampf(_camera_pitch + event.relative.y * 0.009, 0.15, PI / 2.0)
		_update_camera()
		get_viewport().set_input_as_handled()

func _build_camera() -> void:
	_camera = Camera3D.new()
	# Match the original demo's high, nearly overhead perspective.
	_camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	_camera.fov = 45.5
	add_child(_camera)
	_frame_camera()
	_camera.current = true
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.5
	add_child(light)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101a29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b9d6e6")
	environment.environment.ambient_light_energy = 0.55
	add_child(environment)

func _build_hud() -> void:
	var canvas = CanvasLayer.new()
	add_child(canvas)
	var panel = PanelContainer.new()
	panel.position = Vector2(22, 20)
	canvas.add_child(panel)
	var margin = MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 14)
	panel.add_child(margin)
	var column = VBoxContainer.new()
	margin.add_child(column)
	var title_label = Label.new()
	title_label.text = level.title
	title_label.add_theme_font_size_override("font_size", 24)
	column.add_child(title_label)
	_label = Label.new()
	column.add_child(_label)
	var controls = Label.new()
	controls.text = "WASD / arrows · Move    Z · Undo    Y · Redo    R · Restart"
	column.add_child(controls)
	var camera_controls = Label.new()
	camera_controls.text = "Wheel · Zoom    Middle drag · Orbit    Shift + middle drag · Pan    F · Frame"
	column.add_child(camera_controls)
	var row = HBoxContainer.new()
	column.add_child(row)
	for action in ["Undo", "Redo", "Restart"]:
		var button = Button.new()
		button.text = action
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_history_action.bind(action))
		row.add_child(button)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or not _view:
		return
	var key = event.physical_keycode
	if key == KEY_F:
		_frame_camera()
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_Z, KEY_Y, KEY_R]:
		_history_action({KEY_Z: "Undo", KEY_Y: "Redo", KEY_R: "Restart"}[key])
		get_viewport().set_input_as_handled()
		return
	var direction = Vector3i.ZERO
	match key:
		KEY_W, KEY_UP: direction = Vector3i(0, 0, -1)
		KEY_S, KEY_DOWN: direction = Vector3i(0, 0, 1)
		KEY_A, KEY_LEFT: direction = Vector3i(-1, 0, 0)
		KEY_D, KEY_RIGHT: direction = Vector3i(1, 0, 0)
	if direction != Vector3i.ZERO:
		get_viewport().set_input_as_handled()
		if session.status != &"playing":
			return
		if _busy:
			# OS key repeats must not build a backlog or trigger tap acceleration.
			if not event.echo and _pending_history.is_empty() and _move_queue.size() < INPUT_BUFFER_LIMIT:
				_move_queue.append(direction)
				_fast_animation = true
				if _active_tween and _active_tween.is_valid():
					_active_tween.set_speed_scale(_animation_speed())
		elif session.move(session.player_id(), direction):
			_animate()

func _history_action(action: String) -> void:
	if not _view:
		return
	_move_queue.clear()
	if _busy:
		_pending_history = action
		return
	var changed = true
	match action:
		"Undo": changed = session.undo()
		"Redo": changed = session.redo()
		"Restart": session.restart()
	if changed:
		_animate()

func _animation_speed() -> float:
	return maxf(1.0, step_duration / maxf(0.01, buffered_step_duration)) if _fast_animation else 1.0

func _animate(accelerated: bool = false) -> void:
	_busy = true
	_fast_animation = accelerated
	var duration = minf(step_duration, 0.9 / maxf(1.0, session.stages.size()))
	for stage in session.stages:
		_active_tween = _view.show_state(stage, duration)
		if _active_tween and _active_tween.is_valid():
			_active_tween.set_speed_scale(_animation_speed())
			await _active_tween.finished
	_active_tween = null
	_busy = false
	if session.status != &"playing":
		_move_queue.clear()
	_update_status()
	if not _pending_history.is_empty():
		var action = _pending_history
		_pending_history = ""
		_history_action(action)
		return
	while not _move_queue.is_empty():
		var direction: Vector3i = _move_queue.pop_front()
		if session.move(session.player_id(), direction):
			_animate(true)
			return

func _update_status() -> void:
	match session.status:
		&"won": _label.text = "Level complete! Undo to keep experimenting."
		&"failed": _label.text = "You fell out. Undo or restart to try again."
		_: _label.text = "Explore, push, and solve. Every action can be undone."
	if _status != session.status:
		if session.status == &"won": level_completed.emit()
		if session.status == &"failed": level_failed.emit()
	_status = session.status
