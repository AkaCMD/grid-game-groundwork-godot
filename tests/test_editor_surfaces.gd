extends SceneTree
## Run with a graphical renderer to verify actual highlight pixels and animation.
var failures = 0

func _init() -> void:
	call_deferred("run")

func check(value: bool, message: String) -> void:
	if not value:
		failures += 1
		push_error(message)

func run() -> void:
	var target = SubViewport.new()
	target.size = Vector2i(256, 256)
	target.own_world_3d = true
	target.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(target)
	var world = Node3D.new()
	target.add_child(world)
	var camera = Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 2.0
	camera.position.z = 4.0
	world.add_child(camera)
	camera.current = true
	var mesh = BoxMesh.new()
	var selected = GGBoardView.mesh_node(mesh, Color.WHITE)
	selected.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world.add_child(selected)
	var blocker_mesh = BoxMesh.new()
	blocker_mesh.size = Vector3(0.4, 1, 0.3)
	var blocker = GGBoardView.mesh_node(blocker_mesh, Color(0.2, 0.2, 0.2), Vector3(-0.25, 0, 1))
	blocker.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world.add_child(blocker)
	await create_timer(0.1).timeout
	var surface_point = Vector2i(camera.unproject_position(Vector3(0.35, 0, 0.5)))
	var blocked_point = Vector2i(camera.unproject_position(Vector3(-0.25, 0, 1.15)))
	await RenderingServer.frame_post_draw
	var original = target.get_texture().get_image()
	var surfaces = GGEditorEntitySurfaces.new()
	surfaces.show_entities({&"selected": selected}, [&"selected"], GGEditorEntitySurfaces.BLUE, true)
	var minimum = 1.0
	var maximum = 0.0
	for frame in range(10):
		await create_timer(0.12).timeout
		var pixels = target.get_texture().get_image()
		var color = pixels.get_pixelv(surface_point)
		minimum = minf(minimum, color.r)
		maximum = maxf(maximum, color.r)
		check(color.b > color.r + 0.04, "Rendered selection tints the actual surface blue")
		check(pixels.get_pixelv(blocked_point).is_equal_approx(original.get_pixelv(blocked_point)), "Rendered highlight is hidden behind the foreground entity")
	check(maximum - minimum > 0.08, "Rendered blue highlight smoothly varies over one second")
	surfaces.set_feedback(GGEditorEntitySurfaces.RED, false)
	await create_timer(0.1).timeout
	var red = target.get_texture().get_image().get_pixelv(surface_point)
	await create_timer(0.35).timeout
	var stable_red = target.get_texture().get_image().get_pixelv(surface_point)
	check(red.r > red.b + 0.1 and red.is_equal_approx(stable_red), "Rendered invalid preview stays red without breathing")
	surfaces.set_feedback(GGEditorEntitySurfaces.RED, true)
	minimum = 1.0
	maximum = 0.0
	for frame in range(10):
		await create_timer(0.12).timeout
		var color = target.get_texture().get_image().get_pixelv(surface_point)
		minimum = minf(minimum, color.b)
		maximum = maxf(maximum, color.b)
	check(maximum - minimum > 0.08, "Rendered erase red breathes distinctly from the steady invalid preview")
	surfaces.clear()
	await create_timer(0.1).timeout
	check(target.get_texture().get_image().get_pixelv(surface_point).is_equal_approx(original.get_pixelv(surface_point)), "Removing highlights restores the original rendered material")
	await check_coverage(target, world, camera, surfaces)
	target.free()
	print("Surface rendering: %d failures" % failures)
	quit(1 if failures else 0)

func settled() -> void:
	await create_timer(0.1).timeout
	await RenderingServer.frame_post_draw

func check_coverage(target: SubViewport, world: Node3D, camera: Camera3D, surfaces: GGEditorEntitySurfaces) -> void:
	for child in world.get_children():
		if child != camera: child.free()
	var behind = GGBoardView.mesh_node(BoxMesh.new(), Color.WHITE)
	behind.material_override.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	world.add_child(behind)
	var front = MeshInstance3D.new()
	front.mesh = QuadMesh.new()
	front.position.z = 1.0
	world.add_child(front)
	var roots = {&"front": front, &"behind": behind}
	var left = Vector2i(camera.unproject_position(Vector3(-0.2, 0, 1)))
	var right = Vector2i(camera.unproject_position(Vector3(0.2, 0, 1)))
	var pixels = Image.create(2, 1, false, Image.FORMAT_RGBA8)
	pixels.set_pixel(0, 0, Color(1, 1, 1, 0))
	pixels.set_pixel(1, 0, Color.WHITE)
	var texture = ImageTexture.create_from_image(pixels)
	var standard = StandardMaterial3D.new()
	standard.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	standard.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	standard.albedo_texture = texture
	standard.texture_repeat = false
	standard.uv1_offset.x = 1.0
	front.material_override = standard
	await settled()
	var original = target.get_texture().get_image()
	check(original.get_pixelv(left).r > 0.95 and original.get_pixelv(right).r > 0.95, "Clamp fixture is white across the entire original surface")
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	var tinted = target.get_texture().get_image()
	check(tinted.get_pixelv(left).b > tinted.get_pixelv(left).r + 0.1 and tinted.get_pixelv(right).b > tinted.get_pixelv(right).r + 0.1, "Clamped offset texture highlights the complete visible face")
	surfaces.clear()
	standard.uv1_offset.x = 0.0
	standard.texture_repeat = true
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	tinted = target.get_texture().get_image()
	check(tinted.get_pixelv(left).r > 0.95 and tinted.get_pixelv(right).b > tinted.get_pixelv(right).r + 0.1, "Repeat sampling retains the transparent and opaque halves")
	surfaces.clear()
	standard.texture_repeat = false
	standard.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR
	standard.alpha_scissor_threshold = 0.2
	var filtered_point = Vector2i(camera.unproject_position(Vector3(-0.1, 0, 1)))
	await settled()
	check(target.get_texture().get_image().get_pixelv(filtered_point).r > 0.95, "Linear filtering makes the interpolated alpha pass the scissor threshold")
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	var filtered_color = target.get_texture().get_image().get_pixelv(filtered_point)
	check(filtered_color.b > filtered_color.r + 0.03, "Highlight follows linear alpha filtering at the cutout boundary")
	check(surfaces.pick(roots, Vector3(-0.1, 0, 4), Vector3.FORWARD) == &"front", "Picking follows linear alpha filtering at the cutout boundary")
	surfaces.clear()
	var custom = ShaderMaterial.new()
	custom.shader = Shader.new()
	custom.shader.code = "shader_type spatial; render_mode unshaded; uniform float opacity = 0.0; void fragment() { ALBEDO = vec3(1.0); ALPHA = opacity; }"
	front.material_override = custom
	check(surfaces.pick(roots, Vector3(0, 0, 4), Vector3.FORWARD) == &"behind", "Zero final shader alpha picks the visible entity behind")
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	check(target.get_texture().get_image().get_pixelv(left).is_equal_approx(original.get_pixelv(left)), "Invisible shader surface does not acquire a highlight")
	surfaces.clear()
	custom.set_shader_parameter("opacity", 1.0)
	check(surfaces.pick(roots, Vector3(0, 0, 4), Vector3.FORWARD) == &"front", "Changing final shader alpha immediately restores picking")
	custom.shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; uniform sampler2D sprite : filter_nearest, repeat_disable; void fragment() { ALBEDO = vec3(1.0); ALPHA = texture(sprite, UV).a; }"
	custom.set_shader_parameter("sprite", texture)
	check(surfaces.pick(roots, Vector3(-0.2, 0, 4), Vector3.FORWARD) == &"behind", "Custom shader alpha hole passes through")
	check(surfaces.pick(roots, Vector3(0.2, 0, 4), Vector3.FORWARD) == &"front", "Custom shader opaque texel remains pickable")
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	tinted = target.get_texture().get_image()
	check(tinted.get_pixelv(left).r > 0.95 and tinted.get_pixelv(right).b > tinted.get_pixelv(right).r + 0.1, "Custom shader highlights only its final visible coverage")
	surfaces.clear()
	custom.shader.code = "shader_type spatial; render_mode unshaded, cull_disabled; void fragment() { /* } ALPHA */ ALBEDO = vec3(1.0); if (UV.x < 0.5) { discard; } }"
	check(surfaces.pick(roots, Vector3(-0.2, 0, 4), Vector3.FORWARD) == &"behind", "Shader discard passes through without an ALPHA assignment")
	check(surfaces.pick({&"front": front}, Vector3(0.2, 0, -4), Vector3.BACK) == &"front", "Double-sided shader retains back-face picking")
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	tinted = target.get_texture().get_image()
	check(tinted.get_pixelv(left).r > 0.95 and tinted.get_pixelv(right).b > tinted.get_pixelv(right).r + 0.1, "Discard preserves highlight coverage")
	surfaces.clear()
	custom.shader.code = "shader_type spatial; render_mode unshaded; uniform vec4 tint = vec4(1.0); uniform bool breathing = false; void fragment() { ALBEDO = tint.rgb; ALPHA = tint.a; if (breathing) { discard; } }"
	custom.set_shader_parameter("tint", Color.WHITE)
	custom.set_shader_parameter("breathing", false)
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, true)
	await settled()
	surfaces.set_feedback(GGEditorEntitySurfaces.BLUE, false)
	await settled()
	var custom_color = target.get_texture().get_image().get_pixelv(right)
	check(custom_color.b > custom_color.r + 0.1, "Highlight uniforms do not replace the source shader's tint or breathing uniforms")
	surfaces.clear()
	custom.shader.code = "shader_type spatial; render_mode unshaded; void fragment() { ALBEDO = vec3(1.0); ALPHA = UV.x < 0.5 ? 0.25 : 0.75; ALPHA_SCISSOR_THRESHOLD = 0.5; }"
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	tinted = target.get_texture().get_image()
	check(tinted.get_pixelv(left).r > 0.95 and tinted.get_pixelv(right).b > tinted.get_pixelv(right).r + 0.1, "Custom alpha scissor evaluates coverage before reducing highlight strength")
	surfaces.clear()
	custom.shader.code = 'shader_type spatial; render_mode unshaded;\n#include "res://tests/editor_surface_coverage.gdshaderinc"'
	custom.set_shader_parameter("opacity", 0.0)
	check(surfaces.pick(roots, Vector3(0, 0, 4), Vector3.FORWARD) == &"behind", "Included fragment alpha is evaluated by the renderer")
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	check(target.get_texture().get_image().get_pixelv(right).r > 0.95, "Included fragment keeps transparent highlight coverage")
	surfaces.clear()
	custom.shader = load("res://examples/visuals/quack_cube.gdshader")
	custom.set_shader_parameter("sprite", texture)
	custom.set_shader_parameter("background_color", Color.WHITE)
	check(surfaces.pick(roots, Vector3(-0.2, 0, 4), Vector3.FORWARD) == &"front", "QUACK composites transparent sprite pixels into pickable white background")
	surfaces.show_entities(roots, [&"front"], GGEditorEntitySurfaces.BLUE, false)
	await settled()
	tinted = target.get_texture().get_image()
	check(tinted.get_pixelv(left).b > tinted.get_pixelv(left).r + 0.1, "QUACK white background receives the complete surface highlight")
	surfaces.clear()
