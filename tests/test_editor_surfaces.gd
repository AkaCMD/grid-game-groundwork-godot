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
	target.free()
	print("Surface rendering: %d failures" % failures)
	quit(1 if failures else 0)
