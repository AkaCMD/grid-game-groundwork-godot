extends GGGame

func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and not _busy and _view:
		var keys = [KEY_1, KEY_2, KEY_3, KEY_4, KEY_5, KEY_6, KEY_0]
		var index = keys.find(event.physical_keycode)
		if index >= 0:
			var directions = [Vector3i.DOWN, Vector3i.UP, Vector3i.LEFT, Vector3i.RIGHT, Vector3i.FORWARD, Vector3i.BACK, Vector3i.ZERO]
			if session.act(&"gravity", {"direction": directions[index]}): _animate()
			get_viewport().set_input_as_handled()
			return
	super._unhandled_key_input(event)
