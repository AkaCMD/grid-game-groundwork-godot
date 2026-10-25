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
@export var playtest_scene: PackedScene

func rule() -> GGGameRule:
	return game_rule if game_rule else GGGameRule.new()

func migrate() -> void:
	if schema_version == 1: schema_version = 2

func validate_structure() -> PackedStringArray:
	var errors = PackedStringArray()
	if schema_version not in [1, 2]:
		errors.append("Unsupported level schema: %d" % schema_version)
	var ids = {}
	var definitions = {}
	for entity in entities:
		if not entity or not entity.definition:
			errors.append("An entity is missing its definition.")
			continue
		if entity.entity_id == &"" or ids.has(entity.entity_id):
			errors.append("Entity IDs must be nonempty and unique: %s" % entity.entity_id)
		ids[entity.entity_id] = true
		if entity.orientation < 0 or entity.orientation >= 24:
			errors.append("Invalid orientation: %s" % entity.entity_id)
		var definition = entity.definition
		if definition.definition_id == &"":
			errors.append("An entity definition has an empty ID.")
		if definitions.has(definition.definition_id) and definitions[definition.definition_id] != definition:
			errors.append("Different definitions share ID: %s" % definition.definition_id)
		definitions[definition.definition_id] = definition
		if definition.shape.is_empty():
			errors.append("%s has an empty shape." % entity.entity_id)
		var keys = {}
		for field in definition.fields:
			if not field or field.key == &"" or keys.has(field.key):
				errors.append("Invalid or duplicate property field on %s." % entity.entity_id)
				continue
			keys[field.key] = true
			if not field.accepts(entity.resolved_properties().get(field.key)):
				errors.append("Invalid value for %s on %s." % [field.label, entity.entity_id])
		var own_cells = {}
		for cell in entity.occupied_cells():
			if own_cells.has(cell):
				errors.append("%s has duplicate shape cells." % entity.entity_id)
			own_cells[cell] = true
	return errors

func validate_placement() -> PackedStringArray:
	var errors = validate_structure()
	if errors.is_empty(): errors.append_array(rule().validate_level(self))
	return errors

func validate_references() -> PackedStringArray:
	var errors = PackedStringArray()
	var ids = {}
	for entity in entities:
		if entity: ids[entity.entity_id] = true
	for entity in entities:
		if not entity or not entity.definition: continue
		for field in entity.definition.fields:
			if not field: continue
			var value = entity.resolved_properties().get(field.key)
			if not field.accepts(value): continue
			var references = field.references(value)
			if field.required and field.kind in [GGPropertyField.Kind.ENTITY, GGPropertyField.Kind.ENTITIES] and references.is_empty():
				errors.append("%s requires %s." % [entity.entity_id, field.label])
			for id in references:
				if not ids.has(StringName(id)):
					errors.append("%s: %s references missing entity %s." % [entity.entity_id, field.label, id])
	return errors

func validate() -> PackedStringArray:
	var errors = validate_placement()
	if errors.is_empty(): errors.append_array(validate_references())
	return errors

func copy_entities() -> Array[GGEntityPlacement]:
	var result: Array[GGEntityPlacement] = []
	for entity in entities:
		result.append(entity.copy())
	return result
