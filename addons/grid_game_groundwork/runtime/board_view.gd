@tool
class_name GGBoardView
extends Node3D
## Presentation only. All authoritative coordinates come from session snapshots.

var roots: Dictionary = {}
var _definitions: Dictionary = {}
var _selection: MeshInstance3D
var _selected: StringName = &""

func select_actor(actor_id: StringName) -> void:
	set_selected(actor_id)
	if not _selection:
		var ring = TorusMesh.new()
		ring.inner_radius = 0.57
		ring.outer_radius = 0.66
		_selection = mesh_node(ring, Color("ffe568"))
		_selection.scale.y = 0.2
		add_child(_selection)
	_update_selection()

func set_selected(entity_id: StringName) -> void:
	_selected = entity_id
	for id in roots:
		for visual in roots[id].get_children():
			if visual.has_method("apply_entity_selection"):
				visual.call("apply_entity_selection", id == _selected)

func _process(_delta: float) -> void:
	_update_selection()

func _update_selection() -> void:
	if _selection:
		_selection.visible = roots.has(_selected)
		if _selection.visible:
			_selection.position = roots[_selected].position + Vector3(0, 0.51, 0)

func pick_entity(camera: Camera3D, screen_position: Vector2, state: Dictionary) -> StringName:
	var origin = camera.project_ray_origin(screen_position)
	var direction = camera.project_ray_normal(screen_position)
	var nearest = INF
	var picked: StringName = &""
	for id in state.entities:
		for cell in GGGrid.cells(state.entities[id]):
			var hit = AABB(Vector3(cell) - Vector3.ONE * 0.48, Vector3.ONE * 0.96).intersects_ray(origin, direction)
			if hit != null:
				var distance = origin.distance_squared_to(hit)
				if distance < nearest:
					nearest = distance
					picked = id
	return picked


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
	set_selected(_selected)
	_update_selection()
	return tween

func rebuild(level: GGLevel) -> void:
	for child in get_children():
		remove_child(child)
		child.queue_free()
	roots.clear()
	_selection = null
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
