class_name RotatingBar
extends AnimatableBody3D
## A bar sweeping around like a turnstile arm (a "rotating barrier"). It knocks the
## player back when it hits.

var spin_speed: float = 1.4  # radians per second


func setup(length: float, color: Color) -> void:
	sync_to_physics = true
	var size := Vector3(length, 0.45, 0.35)
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


func _physics_process(delta: float) -> void:
	rotation.y += spin_speed * delta
	# AnimatableBody3D only pushes bodies it moves into; give the player a shove too.
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Player
		var offset := player.global_position + Vector3.UP * 0.8 - global_position
		offset.y = 0.0
		var along := offset.dot(global_transform.basis.x)
		var across := offset.dot(global_transform.basis.z)
		var half_length := 2.6
		if absf(along) < half_length and absf(across) < 0.8 and absf(player.global_position.y + 0.8 - global_position.y) < 1.2:
			var push := global_transform.basis.z * signf(across if across != 0.0 else 1.0)
			player.knockback(push * 9.0 * delta * 12.0)
