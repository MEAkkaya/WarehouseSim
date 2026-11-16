class_name FanZone
extends Area3D
## A column of moving air from an industrial fan. While the player is inside, they
## are pushed along `wind` (horizontal: extra walking speed, vertical: an upward
## acceleration - strong enough updrafts lift you off the floor). Loose items are
## blown around too, light ones most.

var wind: Vector3 = Vector3(6, 0, 0)
var size: Vector3 = Vector3(2.5, 3.0, 8.0)

var _blades: Node3D


## Builds the zone, a visible fan housing and the spinning blades.
func build() -> void:
	collision_layer = 0
	collision_mask = 3  # the world (items) and the player
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	add_child(shape)
	_blades = Node3D.new()
	add_child(_blades)
	for k in 2:
		var blade := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(1.6, 0.12, 0.12)
		blade.mesh = mesh
		blade.rotation.z = k * PI / 2.0
		_blades.add_child(blade)
	# The fan sits at the "upwind" end, facing along the wind.
	_blades.position = -wind.normalized() * (size * wind.normalized()).length() * 0.5
	if wind.normalized().abs().is_equal_approx(Vector3.UP):
		_blades.rotation.x = PI / 2.0
	elif absf(wind.normalized().x) > 0.5:
		_blades.rotation.y = PI / 2.0


func _physics_process(delta: float) -> void:
	_blades.rotate(wind.normalized(), 12.0 * delta)
	for body in get_overlapping_bodies():
		if body is Player:
			(body as Player).add_wind(wind)
		elif body is RigidBody3D and not (body as RigidBody3D).freeze:
			var rigid := body as RigidBody3D
			rigid.apply_central_force(wind * 2.0)  # (a force: light items accelerate more)
			rigid.sleeping = false
