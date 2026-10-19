extends SceneTree

var checks = 0
var failures = 0

func check(value: bool, message: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(message)

func author() -> GGLevelAuthoring:
	var result = GGLevelAuthoring.new()
	var level = GGLevel.new()
	level.palette = GGDefaults.palette()
	result.open(level)
	return result

func _init() -> void:
	test_stable_stroke()
	test_shapes_and_faces()
	test_lifecycle()
	test_erase_and_shape()
	print("Stroke: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_stable_stroke() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	editor.paint(crate, Vector3i(0, 4, 0))
	editor.paint(crate, Vector3i(1, 4, 0))
	var stroke = GGEditorStroke.new(editor)
	stroke.configure(crate, GGEditorStroke.Mode.PAINT)
	var ray = Vector3(0, 10, 0)
	editor.dirty = false
	check(stroke.preview(ray, Vector3.DOWN, 0) == Vector3i(0, 5, 0), "Preview uses the elevated logical surface")
	check(not editor.dirty and editor.level.entities.size() == 2, "Hover changes neither resources nor dirty state")
	stroke.begin()
	check(stroke.sample(ray, Vector3.DOWN, 0), "First stroke sample places an entity")
	check(editor.level.entities.back().cell == Vector3i(0, 5, 0), "Committed placement matches the preview")
	check(stroke.preview(ray, Vector3.DOWN, 0) == Vector3i(0, 5, 0), "Preview stays on this stroke's placed entity instead of rising")
	check(not stroke.sample(ray + Vector3(0.1, 0, 0.1), Vector3.DOWN, 0), "Pointer jitter does not stack within the same stroke")
	check(stroke.sample(ray + Vector3.RIGHT, Vector3.DOWN, 0), "Stroke can continue onto another original surface")
	check(not stroke.sample(ray, Vector3.DOWN, 0) and editor.level.entities.size() == 4, "Revisiting a previous cell does not duplicate it")
	stroke.finish()
	stroke.finish()
	check(editor.undo() and editor.level.entities.size() == 2, "One undo removes all placements in the stroke")
	check(editor.redo() and editor.level.entities.size() == 4, "One redo restores all placements")
	check(stroke.preview(ray, Vector3.DOWN, 0) == Vector3i(0, 6, 0), "A later stroke can stack on previously authored entities")

func test_shapes_and_faces() -> void:
	var editor = author()
	editor.paint(editor.level.palette[3], Vector3i(0, 4, 0))
	var shaped = editor.level.palette[3].duplicate(true) as GGEntityDefinition
	shaped.definition_id = &"shaped_brush"
	shaped.shape.assign([Vector3i.ZERO, Vector3i.DOWN, Vector3i.RIGHT])
	var stroke = GGEditorStroke.new(editor)
	stroke.configure(shaped, GGEditorStroke.Mode.PAINT, 1, true)
	check(stroke.preview(Vector3(0, 10, 0), Vector3.DOWN, 0) == Vector3i(0, 6, 0), "Top face fitting accounts for downward shape cells")
	var ray = Vector3(0, 4, 10)
	var target = Vector3i(0, 4, 2)
	check(stroke.preview(ray, Vector3.FORWARD, 0) == target, "Rotated and mirrored brush aligns to a side face without a plane hit")
	stroke.begin()
	check(stroke.sample(ray, Vector3.FORWARD, 0), "Side-face placement succeeds")
	stroke.finish()
	var placed = editor.level.entities.back()
	check(placed.cell == target and placed.quarter_turns == 1 and placed.mirrored, "Placement retains preview position and brush orientation")
	check(placed.occupied_cells().has(Vector3i(0, 4, 1)) and editor.level.validate().is_empty(), "Transformed contacting cells touch without overlapping")
	check(editor.undo() and editor.level.entities.size() == 1, "Shaped stroke is undoable")
	stroke.preview(ray, Vector3.FORWARD, 0)
	check(editor.redo(), "Preview does not clear redo")
	check(stroke.preview(Vector3(20, 4, 10), Vector3.FORWARD, 0) == null, "A ray missing both surfaces and plane has no placement")
	check(stroke.preview(Vector3(20, 10, 0), Vector3.DOWN, -2) == Vector3i(20, -2, 0), "Missing surfaces fall back to the selected height")

func test_lifecycle() -> void:
	var editor = author()
	var stroke = GGEditorStroke.new(editor)
	var crate = editor.level.palette[3]
	var ray = Vector3(0, 10, 0)
	stroke.configure(crate, GGEditorStroke.Mode.PAINT)
	stroke.begin()
	stroke.sample(ray, Vector3.DOWN, 0)
	check(editor.undo() and not stroke.is_active(), "Undo ends the active stroke")
	check(not stroke.sample(ray + Vector3.RIGHT, Vector3.DOWN, 0), "Late pointer samples after undo cannot mutate the level")
	check(editor.redo() and editor.level.entities.size() == 1, "Late samples do not discard redo")
	stroke.begin()
	stroke.configure(crate, GGEditorStroke.Mode.PAINT)
	check(stroke.is_active(), "UI refresh with identical brush settings preserves the stroke")
	stroke.configure(crate, GGEditorStroke.Mode.PAINT, 1)
	check(not stroke.is_active(), "A changed brush ends the previous stroke")
	stroke.begin()
	var other = GGLevel.new()
	other.palette = GGDefaults.palette()
	editor.open(other)
	check(not stroke.is_active(), "Opening another level ends the stroke")
	check(not stroke.sample(ray, Vector3.DOWN, 0) and other.entities.is_empty(), "Old pointer samples cannot paint into a newly opened level")
	stroke.configure(other.palette[4], GGEditorStroke.Mode.PAINT)
	stroke.begin()
	check(stroke.sample(ray, Vector3.DOWN, 0), "Non-solid entities can be painted")
	stroke.finish()
	stroke.begin()
	check(not stroke.sample(ray, Vector3.DOWN, 0), "A later stroke cannot duplicate an identical non-solid entity")
	stroke.finish()
	check(editor.undo() and other.entities.is_empty(), "An empty stroke adds no undo entry")

func test_erase_and_shape() -> void:
	var editor = author()
	var crate = editor.level.palette[3]
	editor.paint(crate, Vector3i.ZERO)
	editor.paint(crate, Vector3i.RIGHT)
	var first = editor.level.entities[0].entity_id
	var second = editor.level.entities[1].entity_id
	var stroke = GGEditorStroke.new(editor)
	stroke.configure(crate, GGEditorStroke.Mode.ERASE)
	stroke.begin()
	var ray = Vector3(0, 5, 0)
	check(stroke.sample(ray, Vector3.RIGHT, 0, first), "Erase uses the picked Entity even if the ray misses the plane")
	check(not stroke.sample(ray, Vector3.RIGHT, 0, first), "Repeated erase samples are harmless")
	check(stroke.sample(ray, Vector3.RIGHT, 0, second), "Erase continues through multiple entities")
	stroke.finish()
	check(editor.undo() and editor.level.entities.size() == 2, "One undo restores the entire erased group")
	stroke.configure(crate, GGEditorStroke.Mode.PAINT, 0, false, true)
	stroke.begin()
	check(stroke.sample(Vector3(1, 10, 0), Vector3.DOWN, 0), "Shape painting uses local plane cells")
	check(stroke.sample(Vector3(2, 10, 0), Vector3.DOWN, 0), "Shape painting continues within one stroke")
	stroke.finish()
	check(crate.shape.size() == 3 and editor.undo() and crate.shape == [Vector3i.ZERO], "One undo restores the whole shape stroke")
	stroke.configure(crate, GGEditorStroke.Mode.ERASE, 0, false, true)
	stroke.begin()
	check(not stroke.sample(Vector3(0, 10, 0), Vector3.DOWN, 0), "Shape erasing cannot remove the last cell")
	stroke.finish()
