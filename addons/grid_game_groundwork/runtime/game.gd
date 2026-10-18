class_name GGGame
extends Node3D
## Drop this node into a scene and assign a GGLevel to play an individual level.

signal level_completed
signal level_failed
@export var level: GGLevel
@export_range(0.01, 0.5) var step_duration: float = 0.12
var session = GGSession.new()
var _view: GGBoardView
var _label: Label
var _busy = false
var _status: StringName

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

func _build_camera() -> void:
	var center = Vector3.ZERO
	var bounds = AABB()
	var first = true
	for entity in level.entities:
		for cell in entity.occupied_cells():
			if first:
				bounds = AABB(Vector3(cell), Vector3.ONE)
				first = false
			else:
				bounds = bounds.expand(Vector3(cell) + Vector3.ONE).expand(Vector3(cell))
	center = bounds.get_center() - Vector3.ONE * 0.5
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = maxf(8.0, maxf(bounds.size.x, bounds.size.z) * 1.25 + bounds.size.y * 0.5)
	add_child(camera)
	camera.position = center + Vector3(9, 13, 14)
	camera.look_at(center)
	camera.current = true
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
	var row = HBoxContainer.new()
	column.add_child(row)
	for action in ["Undo", "Redo", "Restart"]:
		var button = Button.new()
		button.text = action
		button.focus_mode = Control.FOCUS_NONE
		button.pressed.connect(_history_action.bind(action))
		row.add_child(button)

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or _busy or not _view:
		return
	var key = event.physical_keycode
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
		if session.move(session.player_id(), direction):
			_animate()

func _history_action(action: String) -> void:
	if _busy or not _view:
		return
	var changed = true
	match action:
		"Undo": changed = session.undo()
		"Redo": changed = session.redo()
		"Restart": session.restart()
	if changed:
		_animate()

func _animate() -> void:
	_busy = true
	var duration = minf(step_duration, 0.9 / maxf(1.0, session.stages.size()))
	for stage in session.stages:
		var tween = _view.show_state(stage, duration)
		if tween and tween.is_valid():
			await tween.finished
	_busy = false
	_update_status()

func _update_status() -> void:
	match session.status:
		&"won": _label.text = "Level complete! Undo to keep experimenting."
		&"failed": _label.text = "You fell out. Undo or restart to try again."
		_: _label.text = "Explore, push, and solve. Every action can be undone."
	if _status != session.status:
		if session.status == &"won": level_completed.emit()
		if session.status == &"failed": level_failed.emit()
	_status = session.status
