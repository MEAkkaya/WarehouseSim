class_name Pendulum
extends Node3D
## A giant pendulum: a ball on a long arm swinging back and forth. Used for the
## wrecking ball (knocks you out) and the safety-training pendulums (just knock you
## back). The ball itself has no collider: touching it is checked by distance.

enum Hit { KNOCK_OUT, KNOCK_BACK }

var arm_length: float = 6.5
var ball_radius: float = 1.0
## Largest swing angle (radians) and the time for a full swing there and back.
var amplitude: float = 0.9
var period: float = 4.2
var hit_mode: Hit = Hit.KNOCK_OUT
## Swing axis: rotation about Z swings along X, about X swings along Z.
var swing_about_z: bool = true

var _time: float = 0.0
var _cooldown: float = 0.0
var _arm_pivot: Node3D
var _ball: Node3D


## Builds the arm and the ball. Call after setting the fields, before add_child.
func build() -> void:
	_arm_pivot = Node3D.new()
	add_child(_arm_pivot)
	var chain := MeshInstance3D.new()
	var chain_mesh := CylinderMesh.new()
	chain_mesh.top_radius = 0.06
	chain_mesh.bottom_radius = 0.06
	chain_mesh.height = arm_length
	chain.mesh = chain_mesh
	chain.position.y = -arm_length / 2.0
	_arm_pivot.add_child(chain)
	_ball = Node3D.new()
	_ball.position.y = -arm_length
	_arm_pivot.add_child(_ball)
	var ball_mesh_instance := MeshInstance3D.new()
	var ball_mesh := SphereMesh.new()
	ball_mesh.radius = ball_radius
	ball_mesh.height = ball_radius * 2.0
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.25, 0.25, 0.28)
	material.metallic = 0.6
	ball_mesh.material = material
	ball_mesh_instance.mesh = ball_mesh
	_ball.add_child(ball_mesh_instance)


func _physics_process(delta: float) -> void:
	_time += delta
	_cooldown = maxf(0.0, _cooldown - delta)
	var angle := amplitude * sin(_time * TAU / period)
	if swing_about_z:
		_arm_pivot.rotation.z = angle
	else:
		_arm_pivot.rotation.x = angle
	if _cooldown > 0.0:
		return
	for node in get_tree().get_nodes_in_group("players"):
		var player := node as Player
		var chest := player.global_position + Vector3.UP * 1.0
		var away := chest - _ball.global_position
		if away.length() < ball_radius + 0.45:
			_cooldown = 2.5
			if hit_mode == Hit.KNOCK_OUT:
				GameState.knocked_out.emit("were hit by the wrecking ball")
			else:
				away.y = 0.0
				player.knockback(away.normalized() * 12.0 + Vector3.UP * 3.0)
