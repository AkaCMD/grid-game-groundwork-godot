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
var _shader_variants: Dictionary = {}
var _probe: SubViewport
var _probe_camera: Camera3D
var _probe_mesh: MeshInstance3D

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
	_shader_variants.clear()

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
				var original = source.get_active_material(surface)
				if original is ShaderMaterial and original.shader:
					material = _shader_highlight(original)
				else:
					material.shader = _standard_highlight(original)
				material.render_priority = 1
				material.set_shader_parameter(material.get_meta("tint_parameter", &"tint"), color)
				material.set_shader_parameter(material.get_meta("breathing_parameter", &"breathing"), breathing)
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
			_copy_instance_uniforms(source, overlay)
			highlights.append(overlay)

func set_feedback(color: Color, breathing: bool) -> void:
	for overlay in highlights:
		if not is_instance_valid(overlay): continue
		for surface in range(overlay.mesh.get_surface_count()):
			var material = overlay.get_surface_override_material(surface)
			material.set_shader_parameter(material.get_meta("tint_parameter", &"tint"), color)
			material.set_shader_parameter(material.get_meta("breathing_parameter", &"breathing"), breathing)

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
				var material = visual.get_active_material(surface.index)
				var coverage_test = Callable()
				if material is ShaderMaterial:
					coverage_test = func(hit: Vector3) -> bool:
						return _shader_covered(visual, surface.index, material, origin, direction, visual.global_transform * hit)
				var hit = _hit_surface(surface, material, local_origin, local_direction, coverage_test)
				if hit == null: continue
				var distance = origin.distance_squared_to(visual.global_transform * hit)
				if distance < closest:
					closest = distance
					result = id
	if is_instance_valid(_probe):
		_probe.free()
		_probe = null
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

func _hit_surface(surface: Dictionary, material: Material, origin: Vector3, direction: Vector3, coverage_test: Callable = Callable()) -> Variant:
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
		if material is ShaderMaterial and material.shader:
			var code = _shader_code(material.shader)
			visible = true if "cull_disabled" in code else (not front if "cull_front" in code else front)
		if visible and _opaque_at(material, uv) and (not coverage_test.is_valid() or coverage_test.call(hit.position)): return hit.position
		cursor = hit.position + direction * 0.00001
	return null

func _opaque_at(material: Material, uv: Vector2) -> bool:
	# ShaderMaterial coverage is evaluated by the renderer after geometric picking.
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
			var size = Vector2(image.get_size())
			if material.texture_filter in [BaseMaterial3D.TEXTURE_FILTER_NEAREST, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS, BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS_ANISOTROPIC]:
				alpha *= _texel_alpha(image, Vector2i((mapped * size).floor()), material.texture_repeat)
			else:
				var pixel = mapped * size - Vector2.ONE * 0.5
				var cell = Vector2i(pixel.floor())
				var weight = pixel - pixel.floor()
				var top = lerpf(_texel_alpha(image, cell, material.texture_repeat), _texel_alpha(image, cell + Vector2i.RIGHT, material.texture_repeat), weight.x)
				var bottom = lerpf(_texel_alpha(image, cell + Vector2i.DOWN, material.texture_repeat), _texel_alpha(image, cell + Vector2i.ONE, material.texture_repeat), weight.x)
				alpha *= lerpf(top, bottom, weight.y)
	return alpha >= _cutoff(material)

static func _cutoff(material: BaseMaterial3D) -> float:
	return material.alpha_scissor_threshold if material.transparency == BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR else 0.001

# Keep the original fragment, uniforms, sampler hints, vertex stage and discard logic.
# Godot forbids early returns in fragment(), so its final brace is the tint seam.
func _shader_highlight(original: ShaderMaterial) -> ShaderMaterial:
	var code = _shader_code(original.shader)
	var tint_parameter = "tint"
	var breathing_parameter = "breathing"
	while RegEx.create_from_string(r"\b" + tint_parameter + r"\b").search(code): tint_parameter = "_gg_" + tint_parameter
	while RegEx.create_from_string(r"\b" + breathing_parameter + r"\b").search(code): breathing_parameter = "_gg_" + breathing_parameter
	var key = "custom:" + code
	if not _shader_variants.has(key):
		var fragment = RegEx.create_from_string(r"\bvoid\s+fragment\s*\(\s*\)")
		var tint_exit = "ALBEDO = %s.rgb; EMISSION = vec3(0.0); ALPHA *= %s ? mix(0.16, 0.48, 0.5 - 0.5 * cos(TIME * 6.283185307)) : 0.55;" % [tint_parameter, breathing_parameter]
		if "ALPHA_SCISSOR_THRESHOLD" in code:
			tint_exit = "if (ALPHA < ALPHA_SCISSOR_THRESHOLD) { discard; } ALPHA_SCISSOR_THRESHOLD = 0.0; " + tint_exit
		var entry = fragment.search(code)
		if entry:
			var start = code.find("{", entry.get_end())
			var end = start + 1
			var depth = 1
			while depth > 0 and end < code.length():
				if code[end] == "{": depth += 1
				if code[end] == "}": depth -= 1
				end += 1
			var body = code.substr(start + 1, end - start - 2)
			code = code.left(start + 1) + "ALPHA = 1.0;" + body + tint_exit + code.substr(end - 1)
		else:
			code += "\nvoid fragment() { ALPHA = 1.0; " + tint_exit + " }"
		var modes = RegEx.create_from_string(r"render_mode\s+([^;]+);")
		var match_modes = modes.search(code)
		var kept: PackedStringArray = []
		if match_modes:
			for mode in match_modes.get_string(1).split(","):
				mode = mode.strip_edges()
				if not mode.begins_with("depth_") and not mode.begins_with("blend_"):
					kept.append(mode)
		code = modes.sub(code, "", true)
		if not kept.has("unshaded"): kept.append("unshaded")
		kept.append_array(["blend_mix", "depth_draw_never"])
		code += "\nrender_mode " + ", ".join(kept) + ";\n"
		code = RegEx.create_from_string(r"shader_type\s+spatial\s*;").sub(code, "shader_type spatial;\nuniform vec4 %s : source_color; uniform bool %s = true;\n" % [tint_parameter, breathing_parameter])
		var shader = Shader.new()
		shader.code = code
		_shader_variants[key] = shader
	var material = ShaderMaterial.new()
	material.shader = _shader_variants[key]
	material.set_meta("tint_parameter", tint_parameter)
	material.set_meta("breathing_parameter", breathing_parameter)
	for parameter in original.shader.get_shader_uniform_list():
		material.set_shader_parameter(parameter.name, original.get_shader_parameter(parameter.name))
	return material

func _standard_highlight(original: Material) -> Shader:
	if not original is BaseMaterial3D: return HIGHLIGHT
	var filters = ["filter_nearest", "filter_linear", "filter_nearest_mipmap", "filter_linear_mipmap", "filter_nearest_mipmap_anisotropic", "filter_linear_mipmap_anisotropic"]
	var hints = filters[original.texture_filter] + (", repeat_enable" if original.texture_repeat else ", repeat_disable")
	if not _shader_variants.has(hints):
		var shader = Shader.new()
		shader.code = HIGHLIGHT.code.replace("filter_nearest, repeat_enable", hints)
		_shader_variants[hints] = shader
	return _shader_variants[hints]

func _shader_covered(source: MeshInstance3D, surface: int, material: ShaderMaterial, origin: Vector3, direction: Vector3, hit: Vector3) -> bool:
	# Spatial shaders that never write alpha or discard are opaque by Godot's
	# shader contract. In particular, QUACK's sprite alpha only affects ALBEDO.
	# Includes require evaluation: they may contain alpha/discard instructions.
	var coverage = RegEx.create_from_string(r"\b(ALPHA|discard)\b|#include")
	if not material.shader or not coverage.search(_shader_code(material.shader)): return true
	# Arbitrary shader programs cannot be evaluated from albedo textures on CPU.
	# Render the actual surface along the pick ray, clipped just beyond this hit,
	# and read final coverage. The tiny isolated viewport never changes the scene.
	# This is material-local coverage, not scene screen/depth-buffer evaluation;
	# see docs/editor-surface-coverage.md for the supported shader contract.
	if not is_instance_valid(_probe):
		_probe = SubViewport.new()
		_probe.size = Vector2i(3, 3)
		_probe.own_world_3d = true
		_probe.transparent_bg = true
		_probe.render_target_update_mode = SubViewport.UPDATE_DISABLED
		source.get_tree().root.add_child(_probe)
		_probe_camera = Camera3D.new()
		_probe_camera.projection = Camera3D.PROJECTION_ORTHOGONAL
		_probe_camera.size = 0.0003
		_probe_camera.near = 0.01
		_probe.add_child(_probe_camera)
		_probe_camera.current = true
		_probe_mesh = MeshInstance3D.new()
		_probe.add_child(_probe_mesh)
	var mesh = ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, source.mesh.surface_get_arrays(surface))
	_probe_mesh.mesh = mesh
	_probe_mesh.material_override = material
	_copy_instance_uniforms(source, _probe_mesh)
	_probe_mesh.transform = source.global_transform
	_probe_camera.position = origin
	_probe_camera.look_at(origin + direction, Vector3.RIGHT if absf(direction.dot(Vector3.UP)) > 0.99 else Vector3.UP)
	_probe_camera.far = origin.distance_to(hit) + 0.0001
	_probe_camera.force_update_transform()
	_probe_mesh.force_update_transform()
	_probe.render_target_update_mode = SubViewport.UPDATE_ONCE
	RenderingServer.force_sync()
	RenderingServer.force_draw(false)
	var image = _probe.get_texture().get_image()
	return image != null and not image.is_empty() and image.get_pixel(1, 1).a > 0.001

static func _shader_code(shader: Shader) -> String:
	return _expand_shader_code(shader.code, shader.resource_path.get_base_dir())

static func _expand_shader_code(code: String, base: String, depth: int = 0) -> String:
	code = _strip_shader_comments(code)
	var includes = RegEx.create_from_string('#include\\s+"([^"\\n]+)"')
	var include = includes.search(code)
	while include and depth < 32:
		var path = include.get_string(1)
		if not path.begins_with("res://"): path = base.path_join(path)
		var resource = load(path) as ShaderInclude
		if not resource: break
		var expanded = _expand_shader_code(resource.code, path.get_base_dir(), depth + 1)
		code = code.left(include.get_start()) + expanded + code.substr(include.get_end())
		include = includes.search(code)
	return code

static func _copy_instance_uniforms(source: MeshInstance3D, target: MeshInstance3D) -> void:
	for parameter in RenderingServer.instance_geometry_get_shader_parameter_list(source.get_instance()):
		target.set_instance_shader_parameter(parameter.name, source.get_instance_shader_parameter(parameter.name))

static func _strip_shader_comments(code: String) -> String:
	# Preserve quoted include paths, including the // in res://.
	var tokens = RegEx.create_from_string(r'(?s)"[^"\n]*"|/\*.*?\*/|//[^\n]*')
	var result = ""
	var cursor = 0
	for token in tokens.search_all(code):
		result += code.substr(cursor, token.get_start() - cursor)
		result += token.get_string() if token.get_string().begins_with('"') else "\n"
		cursor = token.get_end()
	return result + code.substr(cursor)

static func _texel_alpha(image: Image, pixel: Vector2i, repeat_texture: bool) -> float:
	var size = image.get_size()
	pixel = Vector2i(posmod(pixel.x, size.x), posmod(pixel.y, size.y)) if repeat_texture else pixel.clamp(Vector2i.ZERO, size - Vector2i.ONE)
	return image.get_pixelv(pixel).a
