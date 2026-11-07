extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func fixture() -> Dictionary:
	var authoring = GGLevelAuthoring.new()
	var level = GGLevel.new()
	level.palette = GGDefaults.palette()
	authoring.open(level)
	authoring.paint(level.palette[3], Vector3i(0, 2, 0))
	var interaction = GGEditorInteraction.new(authoring)
	interaction.configure_brush(level.palette[3], 0, false)
	return {"authoring": authoring, "interaction": interaction, "definition": level.palette[3], "id": level.entities[0].entity_id}

func _init() -> void:
	test_tool_and_shape_transitions()
	test_height_routing_and_reset()
	test_refresh_invalidates_preview()
	test_open_and_plane_invalidation()
	print("Interaction: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_tool_and_shape_transitions() -> void:
	var f = fixture()
	var interaction: GGEditorInteraction = f.interaction
	check(interaction.set_mode(GGEditorInteraction.Mode.SELECT) and interaction.can_move(), "Select enables entity movement")
	interaction.begin_pointer(Vector3.UP, Vector3.RIGHT, 0, f.id)
	check(interaction.selection.ids() == [f.id], "A Select gesture works without a ray intersection")
	interaction.release_pointer()
	interaction.begin_move()
	interaction.drag_move(Vector3i(3, 2, 0), true)
	check(not interaction.set_mode(GGEditorInteraction.Mode.ERASE) and interaction.can_move(), "A move preview blocks tool changes")
	check(interaction.set_shape_mode(true), "Shape entry cancels an outstanding move")
	check(not interaction.selection.is_moving() and interaction.selection.ids().is_empty(), "Shape entry clears entity selection and its preview")
	check(interaction.mode == GGEditorInteraction.Mode.PAINT and not interaction.can_move() and not interaction.can_erase_entities(), "Shape entry from Select enables cell painting without entity tools")
	check(not interaction.set_mode(GGEditorInteraction.Mode.SELECT), "Select cannot enter shape editing")
	check(interaction.set_mode(GGEditorInteraction.Mode.ERASE) and not interaction.can_erase_entities(), "Shape Erase removes cells rather than entities")
	interaction.set_shape_mode(false)
	check(interaction.mode == GGEditorInteraction.Mode.SELECT and interaction.can_move(), "Leaving shape editing restores the level tool despite shape tool changes")
	interaction.set_mode(GGEditorInteraction.Mode.PAINT)
	interaction.stroke.begin()
	check(not interaction.set_mode(GGEditorInteraction.Mode.ERASE), "An active authoring stroke blocks tool changes")
	interaction.cancel()
	check(not interaction.is_drawing() and interaction.set_mode(GGEditorInteraction.Mode.ERASE) and interaction.can_erase_entities(), "Cancellation releases the stroke before the next tool transition")
	check(not interaction.set_mode(-1) and not interaction.set_mode(3) and interaction.can_erase_entities(), "Unknown tools cannot corrupt interaction state")
	var empty = GGEditorInteraction.new(GGLevelAuthoring.new())
	check(not empty.set_shape_mode(true) and not empty.shape_mode, "Shape editing requires an entity definition")

func test_height_routing_and_reset() -> void:
	var f = fixture()
	var interaction: GGEditorInteraction = f.interaction
	check(interaction.height_target() == GGEditorInteraction.HeightTarget.PAINT, "Idle Paint routes Q/E to the brush")
	interaction.handle_height(2, false, true)
	interaction.configure_brush(f.definition, 1, true)
	check(interaction.stroke.height_offset() == 2, "Brush orientation changes preserve the exact paint offset")
	check(interaction.height_target(true) == GGEditorInteraction.HeightTarget.CAMERA, "Camera gestures take Q/E priority over Paint")
	interaction.set_mode(GGEditorInteraction.Mode.ERASE)
	interaction.set_mode(GGEditorInteraction.Mode.PAINT)
	check(interaction.stroke.height_offset() == 0, "Leaving and reentering Paint resets its temporary height")
	interaction.stroke.adjust_height(3)
	interaction.configure_brush(f.authoring.level.palette[0], 0, false)
	check(interaction.stroke.height_offset() == 0, "Choosing another definition resets the paint height")
	interaction.set_mode(GGEditorInteraction.Mode.SELECT)
	check(interaction.height_target() == GGEditorInteraction.HeightTarget.CAMERA, "Select without an entity leaves Q/E available to the camera")
	interaction.selection.select(f.id)
	check(interaction.height_target() == GGEditorInteraction.HeightTarget.SELECTION, "Select with entities routes Q/E to the selection")
	check(interaction.height_target(true) == GGEditorInteraction.HeightTarget.CAMERA, "Camera gestures take priority over selected-entity height")
	interaction.selection.begin_move()
	check(interaction.height_target() == GGEditorInteraction.HeightTarget.IGNORE, "An ongoing drag ignores height shortcuts")
	interaction.set_shape_mode(true)
	check(interaction.height_target() == GGEditorInteraction.HeightTarget.CAMERA, "Shape editing leaves Q/E available to the camera")
	interaction.stroke.begin()
	check(interaction.height_target() == GGEditorInteraction.HeightTarget.IGNORE, "An ongoing cell stroke ignores height shortcuts")
	interaction.cancel()

func test_refresh_invalidates_preview() -> void:
	var f = fixture()
	var interaction: GGEditorInteraction = f.interaction
	var authoring: GGLevelAuthoring = f.authoring
	interaction.set_mode(GGEditorInteraction.Mode.SELECT)
	interaction.selection.select(f.id)
	interaction.begin_move()
	interaction.drag_move(Vector3i(9, 2, 0), true)
	var entity = authoring.find_entity(f.id)
	entity.cell = Vector3i(5, 2, 0)
	authoring.dirty = false
	var history = authoring._history.size()
	var displayed = interaction.refreshed_level()
	check(displayed == authoring.level and displayed.entities[0].cell == Vector3i(5, 2, 0), "Refresh returns externally edited placements for rendering")
	check(not interaction.selection.is_moving() and interaction.selection.position() == entity.cell, "Refresh reconciles selection before a renderer can reuse preview origins")
	check(not interaction.release_pointer(Vector3i(9, 2, 0)) and entity.cell == Vector3i(5, 2, 0), "A late release cannot commit the invalidated preview")
	check(not authoring.dirty and authoring._history.size() == history, "Refresh invalidation creates no authoring edit")
	interaction.selection.begin_move()
	authoring.level.entities.clear()
	interaction.refreshed_level()
	check(interaction.selection.ids().is_empty() and not interaction.selection.is_moving(), "Refresh prunes externally removed selection members")
	interaction.set_mode(GGEditorInteraction.Mode.PAINT)
	interaction.stroke.begin()
	interaction.refreshed_level()
	check(interaction.stroke.is_active(), "Rebuilding after a stroke sample preserves the ongoing undo group")
	interaction.cancel()
	interaction.set_shape_mode(true)
	var shape = interaction.refreshed_level()
	check(shape != authoring.level and shape.entities.size() == 1 and shape.entities[0].definition == f.definition, "Shape rendering gets an isolated placement with the shared definition")
	check(authoring.level.entities.is_empty(), "Shape preview creation does not add an authored entity")

func test_open_and_plane_invalidation() -> void:
	var f = fixture()
	var interaction: GGEditorInteraction = f.interaction
	interaction.set_mode(GGEditorInteraction.Mode.SELECT)
	interaction.selection.select(f.id)
	interaction.selection.begin_move()
	interaction.selection.preview_move(Vector3i(4, 2, 0))
	interaction.set_plane(Vector3i.BACK)
	check(not interaction.selection.is_moving() and interaction.stroke.plane_normal == Vector3i.BACK, "Changing plane cancels movement before configuring the stroke plane")
	interaction.set_shape_mode(true)
	interaction.set_mode(GGEditorInteraction.Mode.ERASE)
	var other = GGLevel.new()
	interaction.open(other)
	check(not interaction.shape_mode and interaction.mode == GGEditorInteraction.Mode.SELECT, "Opening a level leaves shape editing and restores the saved level tool")
	check(interaction.selection.ids().is_empty() and interaction.refreshed_level() == other, "Opening a level clears selection and displays the authored level")
	check(not interaction.set_shape_mode(true), "The old brush cannot enable shape editing in a newly opened level")
	interaction.configure_brush(f.definition, 0, false)
	interaction.set_mode(GGEditorInteraction.Mode.PAINT)
	interaction.stroke.adjust_height(4)
	interaction.open(GGLevel.new())
	check(interaction.stroke.height_offset() == 0 and interaction.height_target() == GGEditorInteraction.HeightTarget.CAMERA, "Opening another level clears the exact height and old brush eligibility")
