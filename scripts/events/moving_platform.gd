class_name MovingPlatform
extends AnimatableBody3D
## A platform that slides back and forth along an axis (sine motion). The player
## standing on it is carried along (CharacterBody3D handles moving platforms).

var center: Vector3 = Vector3.ZERO
## Direction of travel (unit vector) and how far it moves either side of `center`.
var axis: Vector3 = Vector3.UP
var amplitude: float = 1.5
var period: float = 6.0
## Phase offset in radians.
var phase: float = 0.0

var _time: float = 0.0


## Builds the platform's shape and look. Call before adding to the tree.
func setup(size: Vector3, color: Color) -> void:
	sync_to_physics = true
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	var mesh_instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	mesh_instance.mesh = mesh
	add_child(mesh_instance)


func _ready() -> void:
	_apply()


func _physics_process(delta: float) -> void:
	_time += delta
	_apply()


func _apply() -> void:
	position = center + axis * amplitude * sin(_time * TAU / period + phase)
