class_name BounceZone
extends Area3D
## Fitness equipment installed by the boss: a trampoline throws the player upwards,
## a treadmill acts as a conveyor belt that carries them along while they stand on it.

enum Kind { TRAMPOLINE, TREADMILL }

var kind: Kind = Kind.TRAMPOLINE
var size: Vector3 = Vector3(2.0, 0.4, 2.0)
## Treadmill: the direction of the belt (flat).
var belt_direction: Vector3 = Vector3(0, 0, -1)
var bounce_speed: float = 9.0
var belt_speed: float = 5.0


func build() -> void:
	collision_layer = 0
	collision_mask = 3
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = size
	shape.shape = box
	shape.position.y = size.y / 2.0
	add_child(shape)
	var pad := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = Vector3(size.x, 0.12, size.z)
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.2, 0.5, 0.95) if kind == Kind.TRAMPOLINE else Color(0.15, 0.15, 0.18)
	mesh.material = material
	pad.mesh = mesh
	pad.position.y = 0.06
	add_child(pad)
	if kind == Kind.TREADMILL:
		# A bright stripe on the belt showing which way it runs.
		var stripe := MeshInstance3D.new()
		var stripe_mesh := BoxMesh.new()
		stripe_mesh.size = Vector3(0.25, 0.02, size.z * 0.6)
		var stripe_material := StandardMaterial3D.new()
		stripe_material.albedo_color = Color(1.0, 0.85, 0.2)
		stripe_mesh.material = stripe_material
		stripe.mesh = stripe_mesh
		stripe.position.y = 0.13
		add_child(stripe)
	else:
		body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node3D) -> void:
	if body is Player and kind == Kind.TRAMPOLINE:
		(body as Player).velocity.y = bounce_speed


func _physics_process(_delta: float) -> void:
	if kind != Kind.TREADMILL:
		return
	var direction := (global_transform.basis * belt_direction).normalized()
	for body in get_overlapping_bodies():
		if body is Player and (body as Player).is_on_floor():
			(body as Player).add_wind(direction * belt_speed)
		elif body is RigidBody3D and not (body as RigidBody3D).freeze:
			(body as RigidBody3D).apply_central_force(direction * 6.0)
