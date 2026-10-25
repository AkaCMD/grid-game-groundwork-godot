@tool
class_name GGFieldsEditor
extends VBoxContainer
## Edits a draft dictionary; the authoring module commits the whole entity.

func configure(level: GGLevel, entity: GGEntityPlacement, overrides: Dictionary) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	for field in entity.definition.fields:
		if not field: continue
		var row = VBoxContainer.new()
		row.name = str(field.key)
		add_child(row)
		var toggle = CheckBox.new()
		toggle.name = "Override"
		toggle.text = field.label if not field.label.is_empty() else str(field.key).capitalize()
		toggle.tooltip_text = "Override shared default; uncheck to inherit"
		toggle.button_pressed = overrides.has(field.key)
		row.add_child(toggle)
		var inherited = entity.definition.defaults().get(field.key, field.value_or_default())
		var value = overrides.get(field.key, inherited)
		var current = [value]
		var input = _make_input(field, value, inherited, level, func(next):
			current[0] = next
			overrides[field.key] = next
		)
		input.name = "Input"
		row.add_child(input)
		_set_enabled(input, toggle.button_pressed)
		toggle.toggled.connect(func(enabled):
			if enabled: overrides[field.key] = current[0]
			else:
				current[0] = inherited
				_set_input_value(input, inherited)
				overrides.erase(field.key)
			_set_enabled(input, enabled)
		)

func _set_input_value(input: Control, value: Variant) -> void:
	if input is CheckBox: input.set_pressed_no_signal(bool(value))
	elif input is SpinBox: input.set_value_no_signal(float(value))
	elif input is LineEdit: input.text = str(value)
	elif input is OptionButton:
		for index in input.item_count:
			if str(input.get_item_metadata(index)) == str(value): input.select(index)
	elif input is ItemList:
		input.deselect_all()
		for index in input.item_count:
			if value.has(input.get_item_metadata(index)): input.select(index, false)
	elif input is HBoxContainer:
		for axis in 3: input.get_child(axis).set_value_no_signal(value[axis])

func _set_enabled(node: Node, enabled: bool) -> void:
	if node is BaseButton: node.disabled = not enabled
	if node is SpinBox: node.editable = enabled
	if node is LineEdit: node.editable = enabled
	if node is ItemList:
		node.mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE
		node.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for child in node.get_children(): _set_enabled(child, enabled)

func _entity_options(level: GGLevel, values: Array) -> Array:
	var options = []
	for entity in level.entities:
		options.append([entity.entity_id, "%s %s" % [entity.definition.display_name, entity.cell]])
	for id in values:
		if str(id) == "": continue
		var found = false
		for option in options:
			if option[0] == StringName(id): found = true
		if not found: options.append([StringName(id), "Missing: %s" % id])
	return options

func _make_input(field: GGPropertyField, value: Variant, inherited: Variant, level: GGLevel, commit: Callable) -> Control:
	match field.kind:
		GGPropertyField.Kind.BOOLEAN:
			var input = CheckBox.new()
			input.text = "Enabled"
			input.button_pressed = bool(value)
			input.toggled.connect(commit)
			return input
		GGPropertyField.Kind.INTEGER, GGPropertyField.Kind.FLOAT:
			var input = SpinBox.new()
			input.allow_greater = true
			input.allow_lesser = true
			input.step = 1.0 if field.kind == GGPropertyField.Kind.INTEGER else 0.1
			input.value = float(value)
			input.value_changed.connect(func(next): commit.call(int(next) if field.kind == GGPropertyField.Kind.INTEGER else next))
			return input
		GGPropertyField.Kind.CHOICE, GGPropertyField.Kind.ENTITY:
			var input = OptionButton.new()
			input.fit_to_longest_item = false
			var options = []
			if field.kind == GGPropertyField.Kind.ENTITY:
				options = [[&"", "None"]] + _entity_options(level, [value, inherited])
			else:
				for choice in field.choices: options.append([choice, choice])
			for option in options:
				input.add_item(option[1])
				var index = input.item_count - 1
				input.set_item_metadata(index, option[0])
				if str(option[0]) == str(value): input.select(index)
			input.item_selected.connect(func(index): commit.call(input.get_item_metadata(index)))
			return input
		GGPropertyField.Kind.ENTITIES:
			var input = ItemList.new()
			input.select_mode = ItemList.SELECT_MULTI
			input.custom_minimum_size.y = 100
			for option in _entity_options(level, value + inherited):
				input.add_item(option[1])
				var index = input.item_count - 1
				input.set_item_metadata(index, option[0])
				if value.has(option[0]): input.select(index, false)
			input.multi_selected.connect(func(_index, _selected):
				var selected = []
				for index in input.get_selected_items(): selected.append(input.get_item_metadata(index))
				commit.call(selected)
			)
			return input
		GGPropertyField.Kind.CELL:
			var input = HBoxContainer.new()
			var coordinates: Array[SpinBox] = []
			for axis in 3:
				var spin = SpinBox.new()
				spin.prefix = ["X", "Y", "Z"][axis]
				spin.allow_greater = true
				spin.allow_lesser = true
				spin.value = value[axis]
				input.add_child(spin)
				coordinates.append(spin)
				spin.value_changed.connect(func(_next): commit.call(Vector3i(int(coordinates[0].value), int(coordinates[1].value), int(coordinates[2].value))))
			return input
	var input = LineEdit.new()
	input.text = str(value)
	input.text_changed.connect(commit)
	return input
