@tool
extends EditorPlugin

var panel: GGEditorPanel

func _enter_tree() -> void:
	panel = GGEditorPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	EditorInterface.get_editor_main_screen().add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	panel.hide()

func _exit_tree() -> void:
	if is_instance_valid(panel):
		panel.queue_free()

func _has_main_screen() -> bool:
	return true

func _get_plugin_name() -> String:
	return "Grid Levels"

func _get_plugin_icon() -> Texture2D:
	return EditorInterface.get_base_control().get_theme_icon("GridContainer", "EditorIcons")

func _make_visible(visible: bool) -> void:
	if is_instance_valid(panel):
		panel.visible = visible

func _handles(value: Object) -> bool:
	return value is GGLevel

func _edit(value: Object) -> void:
	if value is GGLevel and panel:
		panel.request_open(value)

func _save_external_data() -> void:
	if panel and panel.authoring.level and panel.authoring.dirty and not panel.authoring.level.resource_path.is_empty():
		panel.save_current()

func _get_unsaved_status(_for_scene: String) -> String:
	if panel and panel.authoring.dirty:
		return "Grid Levels has unsaved level or entity-shape edits. Save them in the Grid Levels workspace."
	return ""

func _get_state() -> Dictionary:
	if panel and panel.authoring.level:
		return {"level_path": panel.authoring.level.resource_path}
	return {}

func _set_state(state: Dictionary) -> void:
	var path: String = state.get("level_path", "")
	if not path.is_empty() and ResourceLoader.exists(path):
		var level = load(path)
		if level is GGLevel:
			panel.call_deferred("request_open", level)
