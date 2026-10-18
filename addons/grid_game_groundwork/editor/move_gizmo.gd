@tool
class_name GGMoveGizmo
extends Node3D
## World-space translation handles. Drag math is anchored at mouse-down;
## presentation can follow the snapped preview without accumulating error.

const AXES = [Vector3.RIGHT, Vector3.UP, Vector3.BACK]
const COLORS = [Color("ed5555"), Color("65d76e"), Color("569bff")]
const MASKS = [Vector3(1, 0, 0), Vector3(0, 1, 0), Vector3(0, 0, 1), Vector3(1, 1, 0), Vector3(1, 0, 1), Vector3(0, 1, 1)]
var camera: Camera3D
var active_handle = -1
var _handles: Array[Node3D] = []
var _materials: Array[StandardMaterial3D] = []
var _origin: Vector3i
var _plane: Plane
var _start_hit: Vector3

func _ready() -> void:
	for axis in range(3):
		var handle = Node3D.new()
		add_child(handle)
		_handles.append(handle)
		var material = _material(COLORS[axis])
		_materials.append(material)
		var shaft = CylinderMesh.new()
		shaft.top_radius = 0.022
		shaft.bottom_radius = 0.022
		shaft.height = 0.82
		var tip = CylinderMesh.new()
		tip.top_radius = 0.0
		tip.bottom_radius = 0.075
		tip.height = 0.22
		for part in [[shaft, 0.59], [tip, 1.11]]:
			var mesh = MeshInstance3D.new()
			mesh.mesh = part[0]
			mesh.material_override = material
			mesh.position = AXES[axis] * part[1]
			if axis == 0: mesh.rotation.z = -PI / 2.0
			if axis == 2: mesh.rotation.x = PI / 2.0
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			handle.add_child(mesh)
		var label = Label3D.new()
		label.text = ["X", "Y", "Z"][axis]
		label.position = AXES[axis] * 1.35
		label.modulate = COLORS[axis]
		label.font_size = 40
		label.pixel_size = 0.003
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		handle.add_child(label)
	for index in range(3, 6):
		var handle = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = MASKS[index] * 0.25 + (Vector3.ONE - MASKS[index]) * 0.012
		handle.mesh = box
		handle.position = MASKS[index] * 0.375
		var normal: Vector3 = Vector3.ONE - MASKS[index]
		var color: Color = COLORS[AXES.find(normal)]
		color.a = 0.4
		var material = _material(color)
		material.render_priority = 99
		handle.material_override = material
		handle.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(handle)
		_handles.append(handle)
		_materials.append(material)

func _material(color: Color) -> StandardMaterial3D:
	var material = StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.no_depth_test = true
	material.albedo_color = color
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.render_priority = 100
	return material

func _process(_delta: float) -> void:
	update_view()

func update_view() -> void:
	if not camera or not visible:
		return
	# Keep the tool usable at different zoom levels and viewport sizes.
	var depth = -camera.to_local(global_position).z
	var units_per_pixel = 2.0 * maxf(depth, camera.near) * tan(deg_to_rad(camera.fov) * 0.5) / maxf(1.0, camera.get_viewport().get_visible_rect().size.y)
	scale = Vector3.ONE * units_per_pixel * 90.0
	for index in _handles.size():
		_handles[index].visible = depth > camera.near and _usable(index)

func _usable(index: int) -> bool:
	var ray = (global_position - camera.global_position).normalized()
	if index < 3:
		return absf(ray.dot(AXES[index])) < 0.98
	return absf(ray.dot(Vector3.ONE - MASKS[index])) > 0.12

func pick(point: Vector2) -> int:
	if not visible or camera.is_position_behind(global_position):
		return -1
	update_view()
	# Pick the visible square surface before the wider screen-space arrow
	# tolerance, so foreshortened plane handles remain clickable.
	var closest_plane = INF
	var result = -1
	for index in range(3, 6):
		if not _handles[index].visible:
			continue
		var normal: Vector3 = Vector3.ONE - MASKS[index]
		var origin = camera.project_ray_origin(point)
		var hit = Plane(normal, global_position).intersects_ray(origin, camera.project_ray_normal(point))
		if hit == null:
			continue
		var local = to_local(hit)
		var inside = true
		for axis in range(3):
			if MASKS[index][axis] > 0 and (local[axis] < 0.25 or local[axis] > 0.5):
				inside = false
		if inside and origin.distance_squared_to(hit) < closest_plane:
			closest_plane = origin.distance_squared_to(hit)
			result = index
	if result != -1:
		return result
	var closest = 9.0
	for axis in range(3):
		if not _handles[axis].visible:
			continue
		var start = camera.unproject_position(to_global(AXES[axis] * 0.18))
		var end = camera.unproject_position(to_global(AXES[axis] * 1.22))
		var distance = point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))
		if distance < closest:
			closest = distance
			result = axis
	return result

func highlight(index: int) -> void:
	for i in _materials.size():
		var color: Color = COLORS[i] if i < 3 else COLORS[AXES.find(Vector3.ONE - MASKS[i])]
		if i == index: color = Color("ffe16b")
		color.a = 1.0 if i < 3 or i == index else 0.4
		_materials[i].albedo_color = color

func begin_drag(index: int, point: Vector2, origin: Vector3i) -> bool:
	if index < 0 or index >= MASKS.size() or not _usable(index):
		return false
	var normal: Vector3
	if index < 3:
		var view = (camera.global_position - Vector3(origin)).normalized()
		normal = (view - AXES[index] * view.dot(AXES[index])).normalized()
	else:
		normal = Vector3.ONE - MASKS[index]
	_plane = Plane(normal, Vector3(origin))
	var hit = _plane.intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null:
		return false
	_origin = origin
	_start_hit = hit
	active_handle = index
	highlight(index)
	return true

func target_at(point: Vector2) -> Variant:
	if active_handle == -1:
		return null
	var direction = camera.project_ray_normal(point)
	# Avoid huge jumps near a ray/plane singularity.
	if absf(_plane.normal.dot(direction)) < 0.02:
		return null
	var hit = _plane.intersects_ray(camera.project_ray_origin(point), direction)
	if hit == null:
		return null
	var offset: Vector3 = (hit - _start_hit) * MASKS[active_handle]
	return _origin + Vector3i(roundi(offset.x), roundi(offset.y), roundi(offset.z))

func rebase_drag(point: Vector2, origin: Vector3i) -> bool:
	if active_handle == -1:
		return false
	# End can change height even during an X/Z-only drag. Move the drag
	# plane and mouse anchor together, retaining the active handle constraint.
	var plane = Plane(_plane.normal, Vector3(origin))
	var hit = plane.intersects_ray(camera.project_ray_origin(point), camera.project_ray_normal(point))
	if hit == null:
		return false
	_plane = plane
	_origin = origin
	_start_hit = hit
	return true

func end_drag() -> void:
	active_handle = -1
	highlight(-1)
