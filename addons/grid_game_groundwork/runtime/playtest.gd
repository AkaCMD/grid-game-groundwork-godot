class_name GGPlaytest
extends Node
## Supplies the isolated authored snapshot before a custom runtime enters the tree.
@export var level: GGLevel

func _ready() -> void:
	var game = level.playtest_scene.instantiate() if level.playtest_scene else GGGame.new()
	if game.has_method("configure_level"):
		game.call("configure_level", level)
	else:
		var accepts_level = false
		for property in game.get_property_list():
			if property.name == "level": accepts_level = true
		if not accepts_level:
			push_error("The playtest scene must expose level or configure_level(level).")
			game.free()
			return
		game.set("level", level)
	add_child(game)
