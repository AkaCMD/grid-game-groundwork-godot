@tool
class_name GGEditorViewport
extends SubViewportContainer

signal pressed(cell: Vector3i, entity_id: StringName, button: int, shift: bool)
signal dragged(cell: Vector3i, entity_id: StringName)
signal stroke_started
signal stroke_ended
signal layer_changed(value: int)
signal hovered(cell: Vector3i)
signal move_previewed(id: StringName, cell: Vector3i)
signal move_finished(id: StringName, cell: Vector3i, commit: bool)
var camera: Camera3D
var board: GGBoardView
var world: Node3D
var level: GGLevel
var layer: int = 0
var _paint_height = 0.0
var _grid: MeshInstance3D
var _ghost: Node3D
var _selected: Node3D
var _pivot = Vector3(3, 0, 3)
var _yaw = 0.0
var _pitch = deg_to_rad(75.2)
var _zoom = 12.0
var _last_cell = Vector3i(99999, 99999, 99999)
var _drawing = false
var _move_gizmo: GGMoveGizmo
var _selection_id: StringName
var _selection_cell: Vector3i
var _selection_origins: Dictionary = {}
var _move_enabled = false
var _move_target: Vector3i
var _move_valid = true
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
	set_layer(0)
	gui_input.connect(_input_on_view)
	get_window().focus_exited.connect(cancel_move)
	get_window().focus_exited.connect(_stop_navigation)
	focus_exited.connect(_stop_navigation)
	mouse_exited.connect(func():
		if _ghost: _ghost.visible = false
		if is_moving(): return
		_move_gizmo.highlight(-1)
		_drawing = false
		stroke_ended.emit()
	)

func show_level(value: GGLevel) -> void:
	_stop_navigation()
	cancel_move()
	level = value
	board.rebuild(level)

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

func entity_at(point: Vector2) -> StringName:
	if not level:
		return &""
	var origin = camera.project_ray_origin(point)
	var direction = camera.project_ray_normal(point)
	var closest: float = INF
	var result: StringName = &""
	for entity in level.entities:
		for cell in entity.occupied_cells():
			var bounds = AABB(Vector3(cell) - Vector3.ONE * 0.48, Vector3.ONE * 0.96)
			if not entity.resolved_properties().get("solid", true):
				bounds.position.y = cell.y - 0.48
				bounds.size.y = 0.12
			var hit = bounds.intersects_ray(origin, direction)
			if hit != null:
				var distance: float = origin.distance_squared_to(hit)
				if distance < closest:
					closest = distance
					result = entity.entity_id
	return result

func show_ghost(definition: GGEntityDefinition, cell: Vector3i, turns: int, mirrored: bool) -> void:
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
	_tint_ghost(_ghost)

func _tint_ghost(node: Node) -> void:
	if node is MeshInstance3D:
		var material = GGBoardView.material(Color(0.5, 1.0, 0.8, 0.45))
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		node.material_override = material
	for child in node.get_children():
		_tint_ghost(child)

func hide_ghost() -> void:
	if _ghost:
		_ghost.visible = false

func select_entity(id: StringName) -> void:
	var ids: Array[StringName] = []
	if id != &"": ids.append(id)
	select_entities(ids)

func select_entities(ids: Array[StringName]) -> void:
	cancel_move()
	board.set_selected_entities(ids)
	_selection_origins.clear()
	_selection_id = ids.back() if not ids.is_empty() else &""
	_move_gizmo.hide()
	if _selected:
		_selected.free()
		_selected = null
	if not level or ids.is_empty(): return
	for entity in level.entities:
		if entity.entity_id == _selection_id: _selection_cell = entity.cell
	_selected = Node3D.new()
	world.add_child(_selected)
	_selected.position = Vector3(_selection_cell)
	for entity in level.entities:
		if not ids.has(entity.entity_id): continue
		_selection_origins[entity.entity_id] = entity.cell
		for cell in entity.occupied_cells():
			var box = BoxMesh.new()
			box.size = Vector3.ONE * 1.02
			var visual = GGBoardView.mesh_node(box, Color(0.4, 0.9, 1.0, 0.22), Vector3(cell - _selection_cell))
			visual.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			visual.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			visual.material_override.no_depth_test = true
			_selected.add_child(visual)
	_move_gizmo.position = Vector3(_selection_cell)
	_move_gizmo.visible = _move_enabled
	_move_gizmo.update_view()

func set_move_enabled(enabled: bool) -> void:
	if not enabled: cancel_move()
	_move_enabled = enabled
	_move_gizmo.visible = enabled and is_instance_valid(_selected)

func is_moving() -> bool:
	return _move_gizmo != null and _move_gizmo.active_handle != -1

func preview_move(cell: Vector3i, valid: bool) -> void:
	_move_target = cell
	_move_valid = valid
	if _selected:
		_selected.position = Vector3(cell)
		for visual in _selected.get_children():
			visual.material_override.albedo_color = Color(0.4, 0.9, 1.0, 0.22) if valid else Color(1.0, 0.12, 0.12, 0.55)
	for id in _selection_origins:
		if board.roots.has(id):
			board.roots[id].position = Vector3(_selection_origins[id] + cell - _selection_cell)
	_move_gizmo.position = Vector3(cell)

func cancel_move() -> void:
	if is_moving(): _finish_move(false)

func move_position() -> Vector3i:
	return _move_target if is_moving() else _selection_cell

func rebase_move(cell: Vector3i) -> bool:
	if not is_moving() or not _move_gizmo.rebase_drag(_move_pointer, cell):
		return false
	move_previewed.emit(_selection_id, cell)
	return true

func _finish_move(commit: bool) -> void:
	var target = _move_target
	var accepted = commit and _move_valid and target != _selection_cell
	_move_gizmo.end_drag()
	preview_move(_selection_cell, true)
	move_finished.emit(_selection_id, target, accepted)

func is_navigating() -> bool:
	return _looking or not _navigation_keys.is_empty()

func _navigation_available() -> bool:
	if not is_visible_in_tree() or not has_focus():
		return false
	var modal = get_viewport().get_last_exclusive_window()
	return not (is_instance_valid(modal) and modal != get_window() and modal.visible)

func _process(delta: float) -> void:
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

func _release_right(point: Vector2) -> void:
	var pick = _right_pressed and not _right_used and Rect2(Vector2.ZERO, size).has_point(point)
	_end_look()
	if pick and not is_drawing():
		var cell = cell_at(point)
		# Picking an entity also works when the view ray cannot reach the edit plane.
		pressed.emit(cell if cell != null else Vector3i.ZERO, entity_at(point), MOUSE_BUTTON_RIGHT, false)

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

func is_drawing() -> bool:
	return _drawing or is_moving()

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
				if target != null: move_previewed.emit(_selection_id, target)
		elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_move_pointer = event.position
			var target = _move_gizmo.target_at(event.position)
			if target != null: move_previewed.emit(_selection_id, target)
			_finish_move(true)
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
			if handle != -1 and _move_gizmo.begin_drag(handle, event.position, _selection_cell):
				grab_focus()
				_move_target = _selection_cell
				_move_valid = true
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
			_drawing = false
			stroke_ended.emit()
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			grab_focus()
			var cell = cell_at(event.position)
			# Select needs only an entity ray hit, even when looking parallel to
			# the placement plane. Paint and Erase still require a grid cell.
			if cell != null or _move_enabled:
				_drawing = true
				_last_cell = cell if cell != null else Vector3i.ZERO
				stroke_started.emit()
				pressed.emit(_last_cell, entity_at(event.position), event.button_index, event.shift_pressed)
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
		var cell = cell_at(event.position)
		if cell != null:
			hovered.emit(cell)
			if _drawing and event.button_mask & MOUSE_BUTTON_MASK_LEFT and cell != _last_cell:
				_last_cell = cell
				dragged.emit(cell, entity_at(event.position))
		elif _ghost:
			_ghost.visible = false
	elif event is InputEventKey and event.pressed and event.physical_keycode == KEY_F:
		frame_level()
		accept_event()
