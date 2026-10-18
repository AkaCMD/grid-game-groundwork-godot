@tool
class_name GGEditorEntitySurfaces
extends RefCounted
## Editor-only mesh picking and surface overlays; authored resources stay untouched.

const HIGHLIGHT = preload("res://addons/grid_game_groundwork/editor/surface_highlight.gdshader")
const BLUE = Color(0.12, 0.42, 1.0)
const RED = Color(1.0, 0.12, 0.12)
const OVERLAY = &"_gg_editor_surface_overlay"
var highlights: Array[MeshInstance3D] = []
var _geometry: Dictionary = {}
var _images: Dictionary = {}

func clear() -> void:
	for overlay in highlights:
		if not is_instance_valid(overlay): continue
		# Keep materials alive until MeshInstance3D finishes releasing its surfaces.
		var retained: Array[Material] = []
		for surface in range(overlay.mesh.get_surface_count()):
			retained.append(overlay.get_surface_override_material(surface))
		overlay.free()
	highlights.clear()

func reset() -> void:
	clear()
	_geometry.clear()
	_images.clear()

static func meshes(root: Node) -> Array[MeshInstance3D]:
	var result: Array[MeshInstance3D] = []
	if root.has_meta(OVERLAY): return result
	if root is MeshInstance3D and root.mesh and root.is_visible_in_tree():
		result.append(root)
	for child in root.get_children():
		result.append_array(meshes(child))
	return result

func show_entities(roots: Dictionary, ids: Array[StringName], color: Color, breathing: bool) -> void:
	clear()
	for id in ids:
		if not roots.has(id): continue
		for source in meshes(roots[id]):
			var overlay = MeshInstance3D.new()
			overlay.set_meta(OVERLAY, true)
			overlay.mesh = source.mesh
			overlay.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			overlay.layers = source.layers
			for surface in range(source.mesh.get_surface_count()):
				var material = ShaderMaterial.new()
				material.shader = HIGHLIGHT
				material.render_priority = 1
				material.set_shader_parameter("tint", color)
				material.set_shader_parameter("breathing", breathing)
				var original = source.get_active_material(surface)
				if original is BaseMaterial3D:
					material.set_shader_parameter("face_cull", original.cull_mode)
					if original.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
						material.set_shader_parameter("base_alpha", original.albedo_color.a)
						material.set_shader_parameter("alpha_cutoff", _cutoff(original))
						material.set_shader_parameter("uv_scale", original.uv1_scale)
						material.set_shader_parameter("uv_offset", original.uv1_offset)
						if original.albedo_texture:
							material.set_shader_parameter("use_alpha", true)
							material.set_shader_parameter("alpha_texture", original.albedo_texture)
				overlay.set_surface_override_material(surface, material)
			source.add_child(overlay)
			highlights.append(overlay)

func set_feedback(color: Color, breathing: bool) -> void:
	for overlay in highlights:
		if not is_instance_valid(overlay): continue
		for surface in range(overlay.mesh.get_surface_count()):
			var material = overlay.get_surface_override_material(surface)
			material.set_shader_parameter("tint", color)
			material.set_shader_parameter("breathing", breathing)

func pick(roots: Dictionary, origin: Vector3, direction: Vector3) -> StringName:
	var closest = INF
	var result: StringName = &""
	for id in roots:
		for visual in meshes(roots[id]):
			if is_zero_approx(visual.global_basis.determinant()): continue
			var inverse = visual.global_transform.affine_inverse()
			var local_origin = inverse * origin
			var local_direction = (inverse.basis * direction).normalized()
			if visual.mesh.get_aabb().intersects_ray(local_origin, local_direction) == null: continue
			for surface in _surfaces(visual.mesh):
				var hit = _hit_surface(surface, visual.get_active_material(surface.index), local_origin, local_direction)
				if hit == null: continue
				var distance = origin.distance_squared_to(visual.global_transform * hit)
				if distance < closest:
					closest = distance
					result = id
	return result

func _surfaces(mesh: Mesh) -> Array:
	if _geometry.has(mesh): return _geometry[mesh]
	var surfaces: Array = []
	for index in range(mesh.get_surface_count()):
		var arrays = mesh.surface_get_arrays(index)
		if arrays.is_empty() or arrays[Mesh.ARRAY_VERTEX] == null: continue
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var uvs: PackedVector2Array = arrays[Mesh.ARRAY_TEX_UV] if arrays[Mesh.ARRAY_TEX_UV] != null else PackedVector2Array()
		var faces = PackedVector3Array()
		var face_uvs = PackedVector2Array()
		var count = indices.size() if not indices.is_empty() else vertices.size()
		for vertex in range(count):
			var at = indices[vertex] if not indices.is_empty() else vertex
			faces.append(vertices[at])
			face_uvs.append(uvs[at] if at < uvs.size() else Vector2.ZERO)
		var triangles = TriangleMesh.new()
		if not faces.is_empty() and triangles.create_from_faces(faces):
			surfaces.append({"index": index, "triangles": triangles, "faces": faces, "uvs": face_uvs})
	_geometry[mesh] = surfaces
	return surfaces

func _hit_surface(surface: Dictionary, material: Material, origin: Vector3, direction: Vector3) -> Variant:
	# Continue past discarded faces, including a transparent front of a closed mesh.
	var cursor = origin
	for attempt in range(surface.faces.size() / 3):
		var hit: Dictionary = surface.triangles.intersect_ray(cursor, direction)
		if hit.is_empty(): return null
		var face = int(hit.face_index) * 3
		var a: Vector3 = surface.faces[face]
		var b: Vector3 = surface.faces[face + 1]
		var c: Vector3 = surface.faces[face + 2]
		var weights = Geometry3D.get_triangle_barycentric_coords(hit.position, a, b, c)
		var uv: Vector2 = surface.uvs[face] * weights.x + surface.uvs[face + 1] * weights.y + surface.uvs[face + 2] * weights.z
		var front = (c - a).cross(b - a).dot(direction) < 0.0
		var visible = front
		if material is BaseMaterial3D:
			visible = material.cull_mode == BaseMaterial3D.CULL_DISABLED or (front if material.cull_mode == BaseMaterial3D.CULL_BACK else not front)
		if visible and _opaque_at(material, uv): return hit.position
		cursor = hit.position + direction * 0.00001
	return null

func _opaque_at(material: Material, uv: Vector2) -> bool:
	# Custom shaders may composite sprite alpha onto an opaque background (QUACK).
	if not material is BaseMaterial3D or material.transparency == BaseMaterial3D.TRANSPARENCY_DISABLED:
		return true
	var alpha: float = material.albedo_color.a
	if material.albedo_texture:
		var texture: Texture2D = material.albedo_texture
		if not _images.has(texture):
			var pixels = texture.get_image()
			if pixels and pixels.is_compressed(): pixels.decompress()
			_images[texture] = pixels
		var image: Image = _images[texture]
		if image and not image.is_empty():
			var mapped = uv * Vector2(material.uv1_scale.x, material.uv1_scale.y) + Vector2(material.uv1_offset.x, material.uv1_offset.y)
			mapped = Vector2(fposmod(mapped.x, 1.0), fposmod(mapped.y, 1.0)) if material.texture_repeat else mapped.clamp(Vector2.ZERO, Vector2.ONE)
			alpha *= image.get_pixel(mini(int(mapped.x * image.get_width()), image.get_width() - 1), mini(int(mapped.y * image.get_height()), image.get_height() - 1)).a
	return alpha >= _cutoff(material)

static func _cutoff(material: BaseMaterial3D) -> float:
	return material.alpha_scissor_threshold if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.001
