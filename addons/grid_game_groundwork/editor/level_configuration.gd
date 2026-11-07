@tool
extends RefCounted
## Stored resources reachable from an authored level.

class StoredResources:
	var properties: Dictionary[Resource, PackedStringArray] = {}
	var resources: Array[Resource] = []
	var external: Dictionary[String, Resource] = {}

	func include(value: Variant) -> void:
		# Keep script identities and scene assets external to the configuration.
		if value is Script or value is PackedScene:
			return
		if value is Resource:
			if properties.has(value):
				return
			var names = PackedStringArray()
			properties[value] = names
			for property in value.get_property_list():
				if property.usage & PROPERTY_USAGE_STORAGE:
					names.append(property.name)
					include(value.get(property.name))
			properties[value] = names
			resources.append(value)
			var path: String = value.resource_path
			if not path.contains("::") and path.get_extension() in ["tres", "res"]:
				external[path] = value
		elif value is Array:
			for item in value:
				include(item)
		elif value is Dictionary:
			for item in value.values():
				include(item)

	func copy_into(destinations: Dictionary[Resource, Resource]) -> void:
		for resource in resources:
			for name in properties[resource]:
				destinations[resource].set(name, _remap(resource.get(name), destinations))

	func _remap(value: Variant, destinations: Dictionary[Resource, Resource]) -> Variant:
		if value is Resource:
			return destinations.get(value, value)
		if value is Array:
			var copied = value.duplicate()
			for index in copied.size():
				copied[index] = _remap(value[index], destinations)
			return copied
		if value is Dictionary:
			var copied = value.duplicate()
			for key in value:
				copied[key] = _remap(value[key], destinations)
			return copied
		return value

var last_error := ""
var _level: GGLevel
var _stored = StoredResources.new()

func _init(level: GGLevel) -> void:
	_level = level
	_stored.include(level)

func contains(resource: Resource) -> bool:
	return _stored.properties.has(resource)

func isolated_level() -> GGLevel:
	var copies: Dictionary[Resource, Resource] = {}
	for resource in _stored.resources:
		copies[resource] = resource.duplicate(false)
	_stored.copy_into(copies)
	return copies[_level]

func restore_saved() -> bool:
	var saved = StoredResources.new()
	# Read without updating the cache. One missing file must leave live edits intact.
	for path in _stored.external:
		var resource: Resource
		if FileAccess.file_exists(path):
			resource = ResourceLoader.load(path, "", ResourceLoader.CACHE_MODE_IGNORE_DEEP)
		if resource == null:
			last_error = "Could not reload %s while discarding edits." % path
			return false
		saved.include(resource)
	var destinations: Dictionary[Resource, Resource] = {}
	for resource in saved.resources:
		var path = resource.resource_path
		var destination: Resource
		if path.is_empty() or path.contains("::"):
			destination = resource.duplicate(false)
		else:
			destination = ResourceLoader.load(path)
		if destination == null:
			last_error = "Could not restore %s while discarding edits." % path
			return false
		destinations[resource] = destination
	saved.copy_into(destinations)
	return true

func save(path: String) -> Error:
	# Built-in resources are serialized by their containing resource.
	for external_path in _stored.external:
		var resource = _stored.external[external_path]
		if resource == _level:
			continue
		var error = ResourceSaver.save(resource, external_path)
		if error != OK:
			last_error = "Could not save referenced configuration: " + external_path
			return error
	var temporary = path.get_basename() + ".saving.tres"
	var error = ResourceSaver.save(_level, temporary)
	if error == OK:
		error = DirAccess.rename_absolute(ProjectSettings.globalize_path(temporary), ProjectSettings.globalize_path(path))
	if error == OK:
		_level.take_over_path(path)
	else:
		last_error = "Could not save %s (error %d)." % [path, error]
	return error
