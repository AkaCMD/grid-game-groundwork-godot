@tool
class_name GGBoardView
extends Node3D
## Presentation only. All authoritative coordinates come from session snapshots.

var roots: Dictionary = {}
var _definitions: Dictionary = {}

func configure(level: GGLevel) -> void:
	_definitions.clear()
	for entity in level.entities:
		_definitions[entity.entity_id] = entity.definition

func show_state(state: Dictionary, duration: float = 0.0) -> Tween:
	var tween: Tween
	if duration > 0.0:
		tween = create_tween().set_parallel(true)
	for id in roots.keys():
		if not state.entities.has(id):
			roots[id].queue_free()
			roots.erase(id)
	for id in state.entities:
		var entity: Dictionary = state.entities[id]
		if not _definitions.has(id):
			continue
		if not roots.has(id):
			var visual = make_visual(_definitions[id], entity.properties, entity.get("state", {}))
			add_child(visual)
			roots[id] = visual
			visual.position = Vector3(entity.cell)
		var root: Node3D = roots[id]
		root.rotation.y = -entity.turns * PI / 2.0
		root.scale.x = -1.0 if entity.mirror else 1.0
		if tween:
			tween.tween_property(root, "position", Vector3(entity.cell), duration).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		else:
			root.position = Vector3(entity.cell)
		for visual in root.get_children():
			if visual.has_method("apply_entity_state"):
				visual.call("apply_entity_state", entity.get("state", {}))
	return tween

func rebuild(level: GGLevel) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	roots.clear()
	configure(level)
	var entities = {}
	for entity in level.entities:
		if entity.definition:
			entities[entity.entity_id] = {"cell": entity.cell, "turns": entity.quarter_turns, "mirror": entity.mirrored, "properties": entity.resolved_properties(), "state": {}}
	show_state({"entities": entities})

static func material(color: Color) -> StandardMaterial3D:
	var result = StandardMaterial3D.new()
	result.albedo_color = color
	result.roughness = 0.72
	return result

static func mesh_node(mesh: Mesh, color: Color, position: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var node = MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material(color)
	node.position = position
	return node

static func make_visual(definition: GGEntityDefinition, properties: Dictionary, state: Dictionary = {}) -> Node3D:
	var root = Node3D.new()
	if definition.visual_scene:
		var visual = definition.visual_scene.instantiate()
		if visual.has_method("configure_entity"):
			visual.call("configure_entity", definition, properties)
		if visual.has_method("apply_entity_state"):
			visual.call("apply_entity_state", state)
		root.add_child(visual)
		return root
	var color = definition.color
	for cell in definition.shape:
		if not properties.get("solid", true):
			var marker = TorusMesh.new()
			marker.inner_radius = 0.25
			marker.outer_radius = 0.37
			var marker_node = mesh_node(marker, color, Vector3(cell) + Vector3(0, -0.43, 0))
			marker_node.scale.y = 0.35
			root.add_child(marker_node)
		else:
			var box = BoxMesh.new()
			box.size = Vector3.ONE * 0.91
			var offset = Vector3(cell)
			if properties.get("ground", false):
				box.size = Vector3(0.98, 0.18, 0.98)
				offset.y += 0.40
			root.add_child(mesh_node(box, color, offset))
			if properties.get("player", false):
				var cap = BoxMesh.new()
				cap.size = Vector3(0.6, 0.07, 0.6)
				root.add_child(mesh_node(cap, Color("f7f7ed"), offset + Vector3(0, 0.48, 0)))
	return root
