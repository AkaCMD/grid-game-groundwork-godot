@tool
extends Node3D
## Six independent face UVs repeat the full original sprite on every cube face.
var _material: ShaderMaterial
var _is_duck = false
var _hungry: Texture2D
var _fed: Texture2D

func configure_entity(definition: GGEntityDefinition, properties: Dictionary) -> void:
	var sprite: String = properties.get("sprite", "ice")
	_hungry = load("res://examples/assets/quack/%s.png" % sprite)
	_fed = load("res://examples/assets/quack/stuffed_duck.png") if properties.get("player", false) else _hungry
	_is_duck = properties.get("player", false)
	_material = ShaderMaterial.new()
	_material.shader = preload("res://examples/visuals/quack_cube.gdshader")
	_material.set_shader_parameter("sprite", _hungry)
	_material.set_shader_parameter("background_color", Color.WHITE)
	for cell in definition.shape:
		for normal in [Vector3.RIGHT, Vector3.LEFT, Vector3.UP, Vector3.DOWN, Vector3.FORWARD, Vector3.BACK]:
			var face = MeshInstance3D.new()
			var quad = QuadMesh.new()
			quad.size = Vector2.ONE * 0.96
			face.mesh = quad
			face.material_override = _material
			face.position = Vector3(cell) + normal * 0.48
			# QuadMesh faces +Z; use an alternate up vector for horizontal faces.
			face.basis = Basis.looking_at(-normal, Vector3.FORWARD if absf(normal.y) > 0.5 else Vector3.UP)
			add_child(face)

func apply_entity_state(state: Dictionary) -> void:
	if _material:
		_material.set_shader_parameter("sprite", _fed if state.get("fed", false) else _hungry)

func apply_entity_selection(selected: bool) -> void:
	if _material:
		_material.set_shader_parameter("background_color", Color.BLACK if selected and _is_duck else Color.WHITE)
