extends Node3D

@export var camera_path: NodePath = NodePath("Camera3D")
@export var texture_path: String = "res://sfondo.png"
@export var parallax_speed: float = 0.2
@export var distanza_z: float = -40.0

var _camera: Camera3D
var _mesh: MeshInstance3D


func _ready():
	if camera_path != NodePath(""):
		_camera = get_node(camera_path)
	else:
		_camera = get_viewport().get_camera_3d()

	var quad = QuadMesh.new()
	quad.size = Vector2(300, 100)

	var mat = StandardMaterial3D.new()
	mat.albedo_texture = load(texture_path)
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED

	_mesh = MeshInstance3D.new()
	_mesh.mesh = quad
	_mesh.material_override = mat
	_mesh.position.z = distanza_z
	add_child(_mesh)


func _process(delta):
	if not _camera:
		return
	_mesh.position.x = _camera.global_position.x * parallax_speed
	_mesh.position.y = _camera.global_position.y * parallax_speed * 0.4
