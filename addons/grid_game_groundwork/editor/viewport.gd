@tool
class_name GGEditorViewport
extends SubViewportContainer

signal pressed(cell: Vector3i, entity_id: StringName, button: int)
signal dragged(cell: Vector3i, entity_id: StringName)
signal stroke_started
signal stroke_ended
signal hovered(cell: Vector3i)
signal move_previewed(id: StringName, cell: Vector3i)
signal move_finished(id: StringName, cell: Vector3i, commit: bool)
var camera: Camera3D
var board: GGBoardView
var world: Node3D
var level: GGLevel
var layer: int = 0
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
var _move_enabled = false
var _move_target: Vector3i
var _move_valid = true
var _move_pointer: Vector2

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
	mouse_exited.connect(func():
		if _ghost: _ghost.visible = false
		if is_moving(): return
		_move_gizmo.highlight(-1)
		_drawing = false
		stroke_ended.emit()
	)

func show_level(value: GGLevel) -> void:
	cancel_move()
	level = value
	board.rebuild(level)

func frame_level() -> void:
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
	board.set_selected(id)
	cancel_move()
	_selection_id = id
	_move_gizmo.hide()
	if _selected:
		_selected.free()
		_selected = null
	if not level:
		return
	for entity in level.entities:
		if entity.entity_id != id:
			continue
		_selected = Node3D.new()
		world.add_child(_selected)
		_selection_cell = entity.cell
		_selected.position = Vector3(entity.cell)
		for cell in entity.occupied_cells():
			var box = BoxMesh.new()
			box.size = Vector3.ONE * 1.02
			var visual = GGBoardView.mesh_node(box, Color(0.4, 0.9, 1.0, 0.22), Vector3(cell - entity.cell))
			visual.material_override.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			visual.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
			visual.material_override.no_depth_test = true
			_selected.add_child(visual)
		_move_gizmo.position = Vector3(entity.cell)
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
	if board.roots.has(_selection_id):
		board.roots[_selection_id].position = Vector3(cell)
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

func _input(event: InputEvent) -> void:
	if not is_moving(): return
	if event is InputEventKey and event.pressed and event.physical_keycode == KEY_ESCAPE:
		cancel_move()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_VISIBILITY_CHANGED and not is_visible_in_tree():
		cancel_move()

func is_drawing() -> bool:
	return _drawing or is_moving()

func _input_on_view(event: InputEvent) -> void:
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
		if _move_enabled and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
			var handle = _move_gizmo.pick(event.position)
			if handle != -1 and _move_gizmo.begin_drag(handle, event.position, _selection_cell):
				grab_focus()
				_move_target = _selection_cell
				_move_valid = true
				_move_pointer = event.position
				accept_event()
				return
		if event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if event.pressed:
				_zoom = clampf(_zoom * (0.9 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.1), 2, 100)
				_camera_position()
			accept_event()
			return
		if event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
			_drawing = false
			stroke_ended.emit()
		if event.pressed and event.button_index in [MOUSE_BUTTON_LEFT, MOUSE_BUTTON_RIGHT]:
			grab_focus()
			var cell = cell_at(event.position)
			if cell != null:
				if event.button_index == MOUSE_BUTTON_LEFT:
					_drawing = true
					_last_cell = cell
					stroke_started.emit()
				pressed.emit(cell, entity_at(event.position), event.button_index)
			accept_event()
	elif event is InputEventMouseMotion:
		if _move_enabled: _move_gizmo.highlight(_move_gizmo.pick(event.position))
		if event.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			if event.shift_pressed:
				_pivot += (-camera.global_basis.x * event.relative.x + camera.global_basis.y * event.relative.y) * _zoom / maxf(1.0, size.y)
			else:
				_yaw -= event.relative.x * 0.009
				_pitch = clampf(_pitch + event.relative.y * 0.009, 0.15, PI / 2.0)
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
