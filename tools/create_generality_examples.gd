extends SceneTree

const GROUND = preload("res://examples/entities/ground.tres")
const PLAYER = preload("res://examples/entities/player.tres")
const GOAL = preload("res://examples/entities/goal.tres")

func _init() -> void:
	_rolling()
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
	result.visual_scene = load("res://examples/visuals/block.tscn")
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
	var floor = definition(&"floor", GROUND.color)
	floor.properties = {"ground": true}
	for x in width:
		for z in depth:
			place(level, StringName("floor_%d_%d" % [x, z]), floor, Vector3i(x, -1, z))

func save_example(level: GGLevel, name: String) -> void:
	level.migrate()
	var error = ResourceSaver.save(level, "res://examples/levels/%s.tres" % name)
	if error != OK:
		push_error("Could not save example: %s" % name)
		quit(1)
	var file = FileAccess.open("res://examples/%s.tscn" % name, FileAccess.WRITE)
	file.store_string('[gd_scene load_steps=3 format=3]\n[ext_resource type="Script" path="res://addons/grid_game_groundwork/runtime/game.gd" id="1"]\n[ext_resource type="Resource" path="res://examples/levels/%s.tres" id="2"]\n[node name="Game" type="Node3D"]\nscript = ExtResource("1")\nlevel = ExtResource("2")\n' % [name])

func _rolling() -> void:
	var level = GGLevel.new()
	level.title = "Marked rolling block: D, D"
	level.game_rule = GGRollingRule.new()
	floor_tiles(level, 5, 3)
	var block = definition(&"block", PLAYER.color, true, true)
	block.properties = {"player": true}
	block.shape.assign([Vector3i.ZERO, Vector3i.UP])
	block.visual_scene = load("res://examples/visuals/rolling.tscn")
	place(level, &"block", block, Vector3i(0, 0, 1))
	var goal = definition(&"goal", GOAL.color, false)
	goal.properties = {"goal": true}
	place(level, &"goal", goal, Vector3i(3, 0, 1))
	save_example(level, "rolling")
