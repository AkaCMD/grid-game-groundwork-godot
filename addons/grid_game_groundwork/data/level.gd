@tool
class_name GGLevel
extends Resource

@export var schema_version: int = 1
@export var title: String = "Untitled level"
@export var gravity_enabled: bool = true
@export var void_height: int = -8
@export var palette: Array[GGEntityDefinition] = []
@export var entities: Array[GGEntityPlacement] = []
@export var game_rule: GGGameRule

func validate() -> PackedStringArray:
	var errors = PackedStringArray()
	if schema_version != 1:
		errors.append("Unsupported level schema: %d" % schema_version)
	var ids = {}
	var occupied = {}
	var definitions = {}
	for entity in entities:
		if not entity or not entity.definition:
			errors.append("An entity is missing its definition.")
			continue
		if entity.entity_id == &"" or ids.has(entity.entity_id):
			errors.append("Entity IDs must be nonempty and unique: %s" % entity.entity_id)
		ids[entity.entity_id] = true
		var definition = entity.definition
		if definition.definition_id == &"":
			errors.append("An entity definition has an empty ID.")
		if definitions.has(definition.definition_id) and definitions[definition.definition_id] != definition:
			errors.append("Different definitions share ID: %s" % definition.definition_id)
		definitions[definition.definition_id] = definition
		if definition.shape.is_empty():
			errors.append("%s has an empty shape." % entity.entity_id)
		var own_cells = {}
		for cell in entity.occupied_cells():
			if own_cells.has(cell):
				errors.append("%s has duplicate shape cells." % entity.entity_id)
			own_cells[cell] = true
			if cell.y <= void_height:
				errors.append("%s starts at or below the fall-out height." % entity.entity_id)
			if entity.resolved_properties().get("solid", true):
				if occupied.has(cell):
					errors.append("Solid entities %s and %s overlap at %s." % [occupied[cell], entity.entity_id, cell])
				occupied[cell] = entity.entity_id
	return errors

func copy_entities() -> Array[GGEntityPlacement]:
	var result: Array[GGEntityPlacement] = []
	for entity in entities:
		result.append(entity.copy())
	return result
