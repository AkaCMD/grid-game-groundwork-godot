extends SceneTree
## Rebuild the shipped example assets using only the public resource model.
var definitions: Dictionary = {}

func _init() -> void:
	var floor_entity = define("ground", "Ground", Color("34475f"), false, {"ground": true})
	floor_entity.affected_by_gravity = false
	var wall = define("wall", "Wall", Color("607186"), false, {})
	wall.affected_by_gravity = false
	define("player", "Player", Color("64d5d0"), true, {"player": true, "can_push": true, "strength": 5.0})
	define("crate", "Crate", Color("f2b65e"), true, {"crate": true, "pushable": true, "transmits_push": false, "weight": 1.0})
	var l_crate = define("crate_l", "L crate", Color("e58655"), true, {"crate": true, "pushable": true, "transmits_push": false, "weight": 3.0})
	l_crate.shape.assign([Vector3i.ZERO, Vector3i.RIGHT, Vector3i(0, 0, -1)])
	var goal = define("goal", "Goal", Color("a8ef79"), false, {"goal": true})
	goal.solid = false
	goal.affected_by_gravity = false
	define("pipe", "Straight pipe", Color("c194e8"), true, {"pipe": true, "pushable": true, "transmits_push": true, "ports": [Vector3i.LEFT, Vector3i.RIGHT]})
	define("pipe_elbow", "Elbow pipe", Color("c194e8"), true, {"pipe": true, "pushable": true, "transmits_push": true, "ports": [Vector3i.LEFT, Vector3i(0, 0, -1)]})
	define("source", "Pipe source", Color("4ce6df"), false, {"pipe": true, "source": true, "ports": [Vector3i.RIGHT]})
	define("destination", "Pipe destination", Color("f08ba9"), false, {"pipe": true, "destination": true, "ports": [Vector3i.LEFT]})
	for definition in definitions.values():
		if definition.properties.get("pipe", false):
			definition.visual_scene = load("res://examples/visuals/pipe.tscn")
		ResourceSaver.save(definition, "res://examples/entities/%s.tres" % definition.definition_id)
	var sokoban = arena("Garden of crates")
	sokoban.game_rule = GGSokobanRule.new()
	add(sokoban, "player", Vector3i(2, 0, 4))
	add(sokoban, "crate", Vector3i(2, 0, 3))
	add(sokoban, "crate_l", Vector3i(4, 0, 4))
	add(sokoban, "goal", Vector3i(2, 0, 1))
	add(sokoban, "goal", Vector3i(4, 0, 1))
	save_example(sokoban, "sokoban")
	var pipes = arena("Connect the current")
	pipes.game_rule = GGPipeRule.new()
	add(pipes, "player", Vector3i(2, 0, 4))
	add(pipes, "source", Vector3i(1, 0, 2))
	add(pipes, "destination", Vector3i(4, 0, 2))
	add(pipes, "pipe", Vector3i(2, 0, 3))
	add(pipes, "pipe", Vector3i(3, 0, 3))
	save_example(pipes, "pipes")
	print("Created standalone Sokoban and pipe examples.")
	quit()

func define(id: String, title: String, color: Color, movable: bool, properties: Dictionary) -> GGEntityDefinition:
	var definition = GGEntityDefinition.new()
	definition.definition_id = StringName(id)
	definition.display_name = title
	definition.color = color
	definition.movable = movable
	definition.properties = properties
	definitions[id] = definition
	return definition

func arena(title: String) -> GGLevel:
	var level = GGLevel.new()
	level.title = title
	for definition in definitions.values():
		level.palette.append(definition)
	for x in range(7):
		for z in range(7):
			add(level, "ground", Vector3i(x, -1, z))
			if x == 0 or x == 6 or z == 0 or z == 6:
				add(level, "wall", Vector3i(x, 0, z))
	return level

func add(level: GGLevel, id: String, cell: Vector3i) -> void:
	var entity = GGEntityPlacement.new()
	entity.entity_id = StringName("%s_%d" % [id, level.entities.size()])
	entity.definition = definitions[id]
	entity.cell = cell
	level.entities.append(entity)

func save_example(level: GGLevel, id: String) -> void:
	assert(level.validate().is_empty())
	var path = "res://examples/levels/%s.tres" % id
	ResourceSaver.save(level, path)
	var scene = '[gd_scene load_steps=3 format=3]\n\n[ext_resource type="Script" path="res://addons/grid_game_groundwork/runtime/game.gd" id="1"]\n[ext_resource type="Resource" path="%s" id="2"]\n\n[node name="%s" type="Node3D"]\nscript = ExtResource("1")\nlevel = ExtResource("2")\n' % [path, id.capitalize()]
	var file = FileAccess.open("res://examples/%s.tscn" % id, FileAccess.WRITE)
	file.store_string(scene)
