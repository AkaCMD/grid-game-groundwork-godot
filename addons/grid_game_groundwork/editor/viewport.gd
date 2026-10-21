@tool
class_name GGEditorViewport
extends SubViewportContainer

signal entity_picked(entity_id: StringName, button: int, shift: bool)
signal layer_changed(value: int)
signal hovered(cell: Vector3i)
signal selection_height_requested(offset: int)
signal paint_height_requested(offset: int)
var selection: GGEditorSelection
var stroke: GGEditorStroke
var camera: Camera3D
var board: GGBoardView
var world: Node3D
var level: GGLevel
var layer: int = 0
var _paint_height = 0.0
var _grid: MeshInstance3D
var _ghost: Node3D
var _surfaces = GGEditorEntitySurfaces.new()
var _erase_enabled = false
var _erase_target: StringName = &""
var _pivot = Vector3(3, 0, 3)
var _yaw = 0.0
var _pitch = deg_to_rad(75.2)
var _zoom = 12.0
var _move_gizmo: GGMoveGizmo
var _move_enabled = false
var _move_pointer: Vector2
var _navigation_keys: Dictionary = {}
var _fly_speed = 8.0
var _right_pressed = false
var _right_used = false
var _right_position: Vector2
var _looking = false
var _previous_mouse_mode = Input.MOUSE_MODE_VISIBLE

func _ready() -> void:
	stretch = true
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	custom_minimum_size = Vector2(400, 360)
	focus_mode = Control.FOCUS_ALL
	var viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	world = Node3D.new()
	viewport.add_child(world)
	board = GGBoardView.new()
	world.add_child(board)
	camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_PERSPECTIVE
	camera.fov = 45.5
	camera.far = 1000.0
	world.add_child(camera)
	camera.current = true
	_camera_position()
	var light = DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	light.light_energy = 1.4
	world.add_child(light)
	var environment = WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("101a29")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color("b0c9db")
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	_grid = MeshInstance3D.new()
	world.add_child(_grid)
	_move_gizmo = GGMoveGizmo.new()
	_move_gizmo.camera = camera
	world.add_child(_move_gizmo)
	_move_gizmo.hide()
	selection.changed.connect(_show_selection)
	selection.preview_changed.connect(_show_move_preview)
	set_layer(0)
	gui_input.connect(_input_on_view)
	get_window().focus_exited.connect(cancel_move)
	get_window().focus_exited.connect(stroke.finish)
	get_window().focus_exited.connect(_stop_navigation)
	get_window().focus_exited.connect(_clear_erase_hover)
	focus_exited.connect(_stop_navigation)
	mouse_exited.connect(func():
		_clear_erase_hover()
		if _ghost: _ghost.visible = false
		if is_moving(): return
		_move_gizmo.highlight(-1)
		stroke.finish()
	)

func show_level(value: GGLevel) -> void:
	# Refreshing placements in the current level must not release held flight keys.
	if value != level: _stop_navigation()
	cancel_move()
	_surfaces.reset()
	_erase_target = &""
	level = value
	board.rebuild(level)
	_show_selection()

func frame_level() -> void:
	_stop_navigation()
	if not level or level.entities.is_empty():
		_pivot = Vector3.ZERO
		_zoom = 12.0
	else:
		var minimum = Vector3(1e6, 1e6, 1e6)
		var maximum = -minimum
		for entity in level.entities:
			for cell in entity.occupied_cells():
				minimum = minimum.min(Vector3(cell))
				maximum = maximum.max(Vector3(cell))
		_pivot = (minimum + maximum) * 0.5
		_zoom = maxf(6.0, maxf(maximum.x - minimum.x, maximum.z - minimum.z) * 1.4 + maximum.y - minimum.y + 2)
	_camera_position()

func set_layer(value: int) -> void:
	layer = value
	_paint_height = float(value)
	hide_ghost()
	layer_changed.emit(layer)
	if not _grid:
		return
	var mesh = ImmediateMesh.new()
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = Color("39485e")
	mesh.surface_begin(Mesh.PRIMITIVE_LINES, material)
	for i in range(-20, 21):
		mesh.surface_add_vertex(Vector3(i - 0.5, layer - 0.49, -20.5))
		mesh.surface_add_vertex(Vector3(i - 0.5, layer - 0.49, 20.5))
		mesh.surface_add_vertex(Vector3(-20.5, layer - 0.49, i - 0.5))
		mesh.surface_add_vertex(Vector3(20.5, layer - 0.49, i - 0.5))
	mesh.surface_end()
	_grid.mesh = mesh

func _camera_position() -> void:
	camera.size = _zoom
	var distance = _zoom / (2.0 * tan(deg_to_rad(camera.fov) * 0.5))
	camera.position = _pivot + Vector3(sin(_yaw) * cos(_pitch), sin(_pitch), cos(_yaw) * cos(_pitch)) * distance
	# Euler rotation remains well-defined when looking straight down.
	camera.rotation = Vector3(-_pitch, _yaw, 0)

func _translate_camera(offset: Vector3) -> void:
	_pivot += offset
	_camera_position()
	var height = _paint_height + offset.y
	if roundi(height) != layer:
		set_layer(roundi(height))
	_paint_height = height

func cell_at(point: Vector2) -> Variant:
	var hit = Plane(Vector3.UP, layer).intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null:
		return null
	return Vector3i(roundi(hit.x), layer, roundi(hit.z))

# Paint uses logical cell faces, keeping custom visual geometry out of occupancy rules.

func input_cell_at(point: Vector2) -> Variant:
	return stroke.preview(camera.project_ray_origin(point), camera.project_ray_normal(point), layer)

func _sample_stroke(point: Vector2) -> void:
	stroke.sample(camera.project_ray_origin(point), camera.project_ray_normal(point), layer, entity_at(point) if _erase_enabled else &"")

func entity_at(point: Vector2) -> StringName:
	if not level: return &""
	return _surfaces.pick(board.roots, camera.project_ray_origin(point), camera.project_ray_normal(point))

func set_erase_enabled(enabled: bool) -> void:
	_erase_enabled = enabled
	_erase_target = &""
	_update_highlights()
	if enabled: _update_erase_hover(get_local_mouse_position())

func _update_highlights() -> void:
	var ids: Array[StringName] = []
	if _erase_enabled:
		if _erase_target != &"": ids.append(_erase_target)
	else:
		ids = selection.ids()
	_surfaces.show_entities(board.roots, ids, GGEditorEntitySurfaces.RED if _erase_enabled or not selection.is_valid() else GGEditorEntitySurfaces.BLUE, _erase_enabled or selection.is_valid())

func _clear_erase_hover() -> void:
	if _erase_target == &"": return
	_erase_target = &""
	_update_highlights()

func _update_erase_hover(point: Vector2) -> void:
	if not _erase_enabled: return
	var id: StringName = &""
	if is_visible_in_tree() and not is_navigating() and not _right_pressed and Rect2(Vector2.ZERO, size).has_point(point):
		id = entity_at(point)
	if id != _erase_target:
		_erase_target = id
		_update_highlights()

func show_ghost(definition: GGEntityDefinition, cell: Vector3i, turns: int, mirrored: bool, valid: bool = true) -> void:
	if is_navigating():
		hide_ghost()
		return
	if _ghost:
		_ghost.free()
	_ghost = GGBoardView.make_visual(definition, definition.defaults())
	world.add_child(_ghost)
	_ghost.position = Vector3(cell)
	_ghost.rotation.y = -turns * PI / 2.0
	_ghost.scale.x = -1 if mirrored else 1
	_tint_ghost(_ghost, Color(0.5, 1.0, 0.8, 0.45) if valid else Color(1.0, 0.2, 0.2, 0.6))

func _tint_ghost(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var material = GGBoardView.material(color)
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.material_override = material
	for child in node.get_children():
		_tint_ghost(child, color)

func hide_ghost() -> void:
	if _ghost:
		_ghost.visible = false

func _show_selection() -> void:
	if not _move_gizmo: return
	# Custom selection hooks remain runtime-only; editor feedback uses surfaces.
	board.set_selected_entities([])
	_update_highlights()
	_show_move_preview()
	_move_gizmo.visible = _move_enabled and not selection.ids().is_empty()
	_move_gizmo.update_view()

func set_move_enabled(enabled: bool) -> void:
	if not enabled: cancel_move()
	_move_enabled = enabled
	_move_gizmo.visible = enabled and not selection.ids().is_empty()

func is_moving() -> bool:
	return selection != null and selection.is_moving()

func _show_move_preview() -> void:
	if not selection.is_moving(): _move_gizmo.end_drag()
	_surfaces.set_feedback(GGEditorEntitySurfaces.RED if _erase_enabled or not selection.is_valid() else GGEditorEntitySurfaces.BLUE, _erase_enabled or selection.is_valid())
	var positions = selection.positions()
	for id in positions:
		if board.roots.has(id): board.roots[id].position = Vector3(positions[id])
	_move_gizmo.position = Vector3(selection.position())

func cancel_move() -> void:
	if selection: selection.finish_move(false)

func rebase_move(cell: Vector3i) -> bool:
	return is_moving() and _move_gizmo.rebase_drag(_move_pointer, cell)

func is_navigating() -> bool:
	return _looking or not _navigation_keys.is_empty()

func _navigation_available() -> bool:
	if not is_visible_in_tree() or not has_focus():
		return false
	var modal = get_viewport().get_last_exclusive_window()
	return not (is_instance_valid(modal) and modal != get_window() and modal.visible)

func _process(delta: float) -> void:
	if _erase_enabled: _update_erase_hover(get_local_mouse_position())
	if not is_navigating() and not _right_pressed:
		return
	if not _navigation_available():
		_stop_navigation()
		return
	var direction = camera.basis.x * (int(_navigation_keys.has(KEY_D)) - int(_navigation_keys.has(KEY_A)))
	direction -= camera.basis.z * (int(_navigation_keys.has(KEY_W)) - int(_navigation_keys.has(KEY_S)))
	direction += Vector3.UP * (int(_navigation_keys.has(KEY_E)) - int(_navigation_keys.has(KEY_Q)))
	if not direction.is_zero_approx():
		_translate_camera(direction.normalized() * _fly_speed * delta)

func _end_look() -> void:
	_right_pressed = false
	if _looking:
		_looking = false
		Input.mouse_mode = _previous_mouse_mode
		if is_inside_tree() and is_visible_in_tree():
			warp_mouse(_right_position)

func _stop_navigation() -> void:
	_navigation_keys.clear()
	_end_look()

func _exit_tree() -> void:
	_stop_navigation()
	if stroke: stroke.finish()

func _release_right(point: Vector2) -> void:
	var pick = _right_pressed and not _right_used and Rect2(Vector2.ZERO, size).has_point(point)
	_end_look()
	if pick and not is_drawing():
		entity_picked.emit(entity_at(point), MOUSE_BUTTON_RIGHT, false)

func _look_camera(relative: Vector2) -> void:
	# Free look rotates in place; keep the orbit pivot compatible with middle-drag.
	var origin = camera.position
	var distance = camera.position.distance_to(_pivot)
	_yaw -= relative.x * 0.009
	_pitch = clampf(_pitch + relative.y * 0.009, -PI / 2.0, PI / 2.0)
	camera.rotation = Vector3(-_pitch, _yaw, 0)
	_pivot = origin - camera.basis.z * distance
	_camera_position()

func _handle_look_input(event: InputEvent) -> bool:
	if not _looking:
		return false
	if event is InputEventMouseMotion:
		if event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			_look_camera(event.relative)
		else:
			_end_look()
		return true
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
			_release_right(_right_position)
		else:
			_adjust_fly_speed(event)
		return true
	return false

func _input(event: InputEvent) -> void:
	if _handle_look_input(event):
		get_viewport().set_input_as_handled()
		return
	if _right_pressed and event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_RIGHT and not event.pressed:
		_release_right(get_global_transform_with_canvas().affine_inverse() * event.position)
		get_viewport().set_input_as_handled()
		return
	if not event is InputEventKey:
		return
	var key = event.physical_keycode if event.physical_keycode != KEY_NONE else event.keycode
	if event.pressed and key == KEY_ESCAPE and (is_navigating() or _right_pressed or is_moving()):
		_stop_navigation()
		cancel_move()
		get_viewport().set_input_as_handled()
		return
	if not event.pressed and _navigation_keys.has(key):
		_navigation_keys.erase(key)
		get_viewport().set_input_as_handled()
		return
	if not _navigation_available() or is_drawing():
		return
	if event.ctrl_pressed or event.alt_pressed or event.meta_pressed:
		_navigation_keys.clear()
		return
	if key in [KEY_Q, KEY_E] and stroke.can_adjust_height() and not _right_pressed and not _looking:
		if event.pressed and not event.echo and not event.shift_pressed:
			paint_height_requested.emit(1 if key == KEY_E else -1)
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_Q, KEY_E] and _move_enabled and not selection.ids().is_empty() and not _right_pressed and not _looking:
		if event.pressed and not event.echo and not event.shift_pressed:
			selection_height_requested.emit(1 if key == KEY_E else -1)
		get_viewport().set_input_as_handled()
		return
	if key in [KEY_W, KEY_A, KEY_S, KEY_D, KEY_Q, KEY_E]:
		if event.pressed and not event.echo:
			_navigation_keys[key] = true
			if _right_pressed: _right_used = true
			hide_ghost()
		get_viewport().set_input_as_handled()

func _adjust_fly_speed(event: InputEventMouseButton) -> void:
	if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		_fly_speed = clampf(_fly_speed * (1.2 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0 / 1.2), 0.25, 128.0)
		_right_used = true

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		_stop_navigation()
		cancel_move()
		if stroke: stroke.finish()
		_clear_erase_hover()

func is_drawing() -> bool:
	return (stroke != null and stroke.is_active()) or is_moving()

func _input_on_view(event: InputEvent) -> void:
	if _handle_look_input(event):
		accept_event()
		return
	if is_moving():
		if event is InputEventMouseMotion:
			_move_pointer = event.position
			if not event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				cancel_move()
			else:
				var target = _move_gizmo.target_at(event.position)
				if target != null: selection.preview_move(target)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_move_pointer = event.position
			var target = _move_gizmo.target_at(event.position)
			if target != null: selection.preview_move(target)
			selection.finish_move(true)
		accept_event()
		return
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			if event.pressed:
				if not is_drawing():
					grab_focus()
					_right_pressed = true
					_right_used = is_navigating()
					_right_position = event.position
			else:
				_release_right(event.position)
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and (is_navigating() or _right_pressed):
			accept_event()
			return
		if _move_enabled and event.button_index == MOUSE_BUTTON_LEFT and event.pressed and not event.shift_pressed:
			var handle = _move_gizmo.pick(event.position)
			if handle != -1 and _move_gizmo.begin_drag(handle, event.position, selection.position()):
				grab_focus()
				selection.begin_move()
				_move_pointer = event.position
				accept_event()
				return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if _right_pressed:
				_adjust_fly_speed(event)
			elif event.pressed:
				_zoom = clampf(_zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 2, 100)
				_camera_position()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			stroke.finish()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			stroke.begin()
			var cell = input_cell_at(event.position)
			# Entity tools also work when the ray cannot reach the paint plane.
			if cell != null or _move_enabled or _erase_enabled:
				var id = entity_at(event.position)
				_sample_stroke(event.position)
				entity_picked.emit(id, event.button_index, event.shift_pressed)
				_update_erase_hover(event.position)
			else:
				stroke.finish()
			accept_event()
	elif event is InputEventMouseMotion:
		if _right_pressed:
			if not event.button_mask & MOUSE_BUTTON_MASK_RIGHT:
				_end_look()
			elif event.position.distance_to(_right_position) >= 4.0:
				_right_used = true
				_looking = true
				_previous_mouse_mode = Input.mouse_mode
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				hide_ghost()
				_move_gizmo.highlight(-1)
				_look_camera(event.relative)
			accept_event()
			return
		if _move_enabled: _move_gizmo.highlight(_move_gizmo.pick(event.position))
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			if event.shift_pressed:
				_translate_camera((-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * _zoom / maxf(1.0, size.y))
			else:
				_yaw -= event.relative.x * 0.009
				_pitch = clampf(_pitch + event.relative.y * 0.009, -PI / 2.0, PI / 2.0)
			_camera_position()
			accept_event()
			return
		_update_erase_hover(event.position)
		var cell = input_cell_at(event.position)
		if cell != null: hovered.emit(cell)
		elif _ghost: _ghost.visible = false
		if stroke.is_active():
			if event.button_mask & MOUSE_BUTTON_MASK_LEFT:
				_sample_stroke(event.position)
				_update_erase_hover(event.position)
			else:
				stroke.finish()
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_F:
		frame_level()
		accept_event()
