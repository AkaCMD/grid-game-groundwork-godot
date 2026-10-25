extends SceneTree

func _init() -> void:
	_rolling()
	_gravity()
	_links()
	quit()

func definition(id: StringName, color: Color, solid: bool = true, movable: bool = false) -> GGEntityDefinition:
	var result = GGEntityDefinition.new()
	result.definition_id = id
	result.display_name = str(id).capitalize()
	result.color = color
	result.solid = solid
	result.movable = movable
	result.affected_by_gravity = movable
	result.properties = {}
	return result

func place(level: GGLevel, id: StringName, definition: GGEntityDefinition, cell: Vector3i, overrides: Dictionary = {}) -> void:
	if not level.palette.has(definition): level.palette.append(definition)
	var entity = GGEntityPlacement.new()
	entity.entity_id = id
	entity.definition = definition
	entity.cell = cell
	entity.overrides = overrides
	level.entities.append(entity)

func floor_tiles(level: GGLevel, width: int, depth: int) -> void:
	var floor = definition(&"floor", Color("60778c"))
	floor.properties = {"ground": true}
	for x in width:
		for z in depth:
			place(level, StringName("floor_%d_%d" % [x, z]), floor, Vector3i(x, -1, z))

func save_example(level: GGLevel, name: String, runtime: String = "res://addons/grid_game_groundwork/runtime/game.gd") -> void:
	level.migrate()
	var error = ResourceSaver.save(level, "res://examples/levels/%s.tres" % name)
	if error != OK:
		push_error("Could not save example: %s" % name)
		quit(1)
	var file = FileAccess.open("res://examples/%s.tscn" % name, FileAccess.WRITE)
	file.store_string('[gd_scene load_steps=3 format=3]\n[ext_resource type="Script" path="%s" id="1"]\n[ext_resource type="Resource" path="res://examples/levels/%s.tres" id="2"]\n[node name="Game" type="Node3D"]\nscript = ExtResource("1")\nlevel = ExtResource("2")\n' % [runtime, name])

func _rolling() -> void:
	var level = GGLevel.new()
	level.title = "Marked rolling block: D, D"
	level.game_rule = GGRollingRule.new()
	floor_tiles(level, 5, 3)
	var block = definition(&"block", Color("344860"), true, true)
	block.properties = {"player": true}
	block.shape.assign([Vector3i.ZERO, Vector3i.UP])
	block.visual_scene = load("res://examples/visuals/rolling.tscn")
	place(level, &"block", block, Vector3i(0, 0, 1))
	var goal = definition(&"goal", Color.GOLD, false)
	goal.properties = {"goal": true}
	place(level, &"goal", goal, Vector3i(3, 0, 1))
	save_example(level, "rolling")

func _gravity() -> void:
	var level = GGLevel.new()
	level.title = "Gravity: 1 down, 2 up, 3 left, 4 right, 5 forward, 6 back, 0 off"
	level.game_rule = GGGravityRule.new()
	level.playtest_scene = load("res://examples/runtime/gravity_host.tscn")
	var wall = definition(&"boundary", Color("4a6777"))
	wall.visual_scene = load("res://examples/visuals/boundary.tscn")
	for x in range(-1, 4):
		for y in range(-1, 4):
			for z in range(-1, 4):
				if x in [-1, 3] or y in [-1, 3] or z in [-1, 3]:
					place(level, StringName("wall_%d_%d_%d" % [x, y, z]), wall, Vector3i(x, y, z))
	var actor = definition(&"actor", Color("56d6c0"), true, true)
	actor.properties = {"player": true, "can_push": true}
	place(level, &"actor", actor, Vector3i(1, 1, 1))
	var crate = definition(&"crate", Color("e6a35e"), true, true)
	crate.properties = {"pushable": true}
	place(level, &"crate", crate, Vector3i(1, 0, 1))
	save_example(level, "gravity", "res://examples/runtime/gravity_game.gd")

func reference_field(key: StringName, label: String, multiple: bool = false) -> GGPropertyField:
	var field = GGPropertyField.new()
	field.key = key
	field.label = label
	field.kind = GGPropertyField.Kind.ENTITIES if multiple else GGPropertyField.Kind.ENTITY
	return field

func _links() -> void:
	var level = GGLevel.new()
	level.title = "Linked mechanisms: hold the switch, cross the door, enter the portal"
	level.game_rule = GGLinksRule.new()
	floor_tiles(level, 9, 4)
	var actor = definition(&"actor", Color("56d6c0"), true, true)
	actor.properties = {"player": true, "can_push": true}
	place(level, &"actor", actor, Vector3i(0, 0, 1))
	var crate = definition(&"crate", Color("e6a35e"), true, true)
	crate.properties = {"pushable": true}
	place(level, &"crate", crate, Vector3i(1, 0, 2))
	var pressure = definition(&"pressure_switch", Color.GOLD, false)
	pressure.properties = {"switch": true}
	pressure.fields.append(reference_field(&"doors", "Controlled doors", true))
	place(level, &"switch", pressure, Vector3i(1, 0, 1), {&"doors": [&"door_a", &"door_b"]})
	var door = definition(&"door", Color("ef6677"))
	door.properties = {"door": true}
	door.visual_scene = load("res://examples/visuals/door.tscn")
	place(level, &"door_a", door, Vector3i(4, 0, 1))
	place(level, &"door_b", door, Vector3i(4, 0, 0))
	var portal = definition(&"portal", Color("ae86ed"), false)
	portal.properties = {"portal": true}
	portal.fields.append(reference_field(&"target", "Portal destination"))
	place(level, &"portal_entry", portal, Vector3i(5, 0, 1), {&"target": &"portal_exit"})
	place(level, &"portal_exit", portal, Vector3i(7, 0, 2))
	var goal = definition(&"goal", Color.LIME_GREEN, false)
	goal.properties = {"goal": true}
	place(level, &"goal", goal, Vector3i(7, 0, 1))
	save_example(level, "links")
