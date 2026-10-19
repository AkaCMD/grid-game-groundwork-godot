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
	for cell in [Vector3i(0, 2, 0), Vector3i(1, 2, 0), Vector3i(3, 2, 0)]:
		result.paint(level.palette[3], cell, 1, true, {"weight": 7})
	return result

func _init() -> void:
	test_selection_and_move()
	test_cancel_and_reconcile()
	test_snap()
	print("Selection: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func test_selection_and_move() -> void:
	var editor = author()
	var selection = GGEditorSelection.new(editor)
	var first = editor.level.entities[0].entity_id
	var second = editor.level.entities[1].entity_id
	selection.select(first)
	selection.select(second, true)
	check(selection.ids() == [first, second] and selection.active_id() == second, "Last selected entity anchors the ordered group")
	selection.ids().clear()
	selection.positions().clear()
	check(selection.ids().size() == 2 and selection.positions().size() == 2, "Consumers cannot mutate selection or origins through queries")
	selection.select(&"", true)
	check(selection.ids().size() == 2, "Shift on empty space retains selection")
	selection.select(second, true)
	check(selection.ids() == [first], "Shift removes an existing member")
	selection.select(second, true)
	editor.dirty = false
	check(selection.begin_move(), "A selected group can begin a preview")
	selection.preview_move(Vector3i(2, 2, 0))
	check(selection.is_valid() and selection.positions()[first] == Vector3i(1, 2, 0), "Preview permits cells vacated by other selected entities")
	check(editor.find_entity(first).cell == Vector3i(0, 2, 0) and not editor.dirty, "Preview leaves authored data and dirty state untouched")
	selection.preview_move(Vector3i(3, 2, 0))
	check(not selection.is_valid(), "A single colliding member invalidates the whole group")
	check(not selection.finish_move(true) and selection.position() == Vector3i(1, 2, 0), "Releasing an invalid preview restores the original positions")
	selection.begin_move()
	selection.preview_move(Vector3i(2, 2, 0))
	check(selection.finish_move(true), "Releasing a valid preview commits the group")
	check(not selection.finish_move(true), "Repeated finish cannot record another edit")
	check(editor.undo() and editor.find_entity(first).cell == Vector3i(0, 2, 0), "One undo restores the entire group")
	check(selection.position() == Vector3i(1, 2, 0), "Undo reconciles the selection anchor")
	check(editor.redo() and selection.position() == Vector3i(2, 2, 0), "Redo reconciles the selection anchor")
	var entity = editor.find_entity(first)
	check(entity.quarter_turns == 1 and entity.mirrored and entity.overrides.weight == 7, "Movement preserves orientation and overrides")

func test_cancel_and_reconcile() -> void:
	var editor = author()
	var selection = GGEditorSelection.new(editor)
	var first = editor.level.entities[0].entity_id
	var second = editor.level.entities[1].entity_id
	selection.select(first)
	selection.begin_move()
	selection.preview_move(Vector3i(8, 2, 0))
	selection.select(second)
	check(not selection.is_moving() and editor.find_entity(first).cell == Vector3i(0, 2, 0), "Changing selection cancels the preview")
	selection.begin_move()
	selection.preview_move(Vector3i(8, 2, 0))
	check(selection.translate(Vector3i.UP), "Keyboard translation cancels any old preview")
	check(editor.find_entity(second).cell == Vector3i(1, 3, 0), "Keyboard translation uses authored origins, not stale preview positions")
	check(editor.undo() and editor.find_entity(second).cell == Vector3i(1, 2, 0), "One undo restores keyboard translation")
	selection.begin_move()
	selection.preview_move(Vector3i(8, 2, 0))
	check(selection.duplicate(), "Duplicate accepts a selected group while cancelling its preview")
	var copied = selection.active_id()
	check(copied != second and editor.find_entity(copied).cell == Vector3i(2, 2, 0), "Duplicate selects copies made from authored positions")
	selection.begin_move()
	selection.preview_move(Vector3i(8, 2, 0))
	check(selection.erase() and selection.ids().is_empty(), "Delete cancels preview and clears deleted selection")
	check(editor.undo() and editor.find_entity(copied) != null and selection.ids().is_empty(), "Undo restores deleted entities without resurrecting selection")
	selection.select(first)
	selection.begin_move()
	selection.preview_move(Vector3i(9, 2, 0))
	editor.erase(first)
	check(selection.ids().is_empty() and not selection.is_moving(), "External authoring deletion cancels and prunes stale selections")
	selection.select(second)
	selection.begin_move()
	var other = editor.level.duplicate(true) as GGLevel
	editor.open(other)
	check(selection.ids().is_empty() and not selection.is_moving(), "Opening another level clears selection even if IDs match")

func test_snap() -> void:
	var editor = author()
	var first = editor.level.entities[0].entity_id
	editor.paint(editor.level.palette[0], Vector3i.ZERO)
	var selection = GGEditorSelection.new(editor)
	selection.select(first)
	check(selection.snap_to_ground() and selection.position() == Vector3i.UP, "Idle End commits the supported position")
	check(editor.undo() and selection.position() == Vector3i(0, 2, 0), "Snap is one undoable edit")
	selection.begin_move()
	selection.preview_move(Vector3i(0, 5, 0))
	check(not selection.snap_to_ground(func(_cell): return false), "Failed projection rebase rejects End")
	check(selection.position() == Vector3i(0, 5, 0) and selection.is_moving(), "Failed rebase retains the previous drag")
	check(selection.snap_to_ground() and selection.position() == Vector3i.UP and selection.is_moving(), "End stages a supported position during a drag")
	check(editor.find_entity(first).cell == Vector3i(0, 2, 0), "Staged End does not change authored position")
	selection.finish_move(false)
	check(selection.position() == Vector3i(0, 2, 0), "Cancelling after End restores the original position")
	check(editor.redo() and selection.position() == Vector3i.UP, "Cancelled preview preserves redo")
