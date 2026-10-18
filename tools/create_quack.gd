extends SceneTree
## Rebuild only the QUACK example; leave the other authored examples intact.
var definitions = {}
var level = GGLevel.new()

func _init() -> void:
	level.title = "QUACK!!! on ICE — Three hungry ducks"
	level.void_height = -5
	level.game_rule = GGQuackRule.new()
	define("duck", true, true, {"player": true, "sprite": "duck"})
	define("bread", false, false, {"bread": true, "sprite": "bread"})
	define("ice", true, false, {"ground": true, "sprite": "ice"})
	define("ice_wall", true, false, {"sprite": "wall"})
	for x in range(-1, 5):
		for z in range(-1, 5):
			add("ice", Vector3i(x, -1, z))
			if x in [-1, 4] or z in [-1, 4]:
				add("ice_wall", Vector3i(x, 0, z))
	for cell in [Vector3i(0, 0, 2), Vector3i(2, 0, 2), Vector3i(3, 0, 2)]:
		add("ice_wall", cell)
	# Upper platform ends just before the lower board, two cells below.
	add("ice", Vector3i(-1, 1, 1))
	add("ice", Vector3i(-2, 1, 1))
	add("duck", Vector3i(-1, 2, 1), &"duck_a")
	add("duck", Vector3i(0, 0, 3), &"duck_b")
	add("duck", Vector3i(0, 0, 0), &"duck_c")
	add("bread", Vector3i(3, 0, 1), &"bread_a")
	add("bread", Vector3i(2, 0, 3), &"bread_b")
	add("bread", Vector3i(1, 0, 2), &"bread_c")
	assert(level.validate().is_empty())
	ResourceSaver.save(level, "res://examples/levels/quack.tres")
	quit()

func define(id: String, solid: bool, movable: bool, properties: Dictionary) -> void:
	var definition = GGEntityDefinition.new()
	definition.definition_id = StringName(id)
	definition.display_name = id.capitalize().replace("_", " ")
	definition.solid = solid
	definition.movable = movable
	definition.affected_by_gravity = movable
	definition.properties = properties
	definition.visual_scene = load("res://examples/visuals/quack.tscn")
	ResourceSaver.save(definition, "res://examples/entities/quack_%s.tres" % id)
	definitions[id] = definition
	level.palette.append(definition)

func add(id: String, cell: Vector3i, entity_id: StringName = &"") -> void:
	var placement = GGEntityPlacement.new()
	placement.definition = definitions[id]
	placement.cell = cell
	placement.entity_id = entity_id if entity_id != &"" else StringName("%s_%d" % [id, level.entities.size()])
	level.entities.append(placement)
