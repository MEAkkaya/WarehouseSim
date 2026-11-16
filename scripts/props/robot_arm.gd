class_name RobotArm
extends Node3D
## A two-joint robot arm (placeholder boxes and cylinders; swap in a model later) that
## turns on its base, reaches a point and holds a box in its gripper. `reach_to()` is a
## coroutine: `await arm.reach_to(point, 0.6)` moves the gripper to a world point.
##
## Built in code. The arm extends along its turret's local -Z; the gripper hangs at the
## end of the forearm. Joint angles come from a small two-link inverse-kinematics
## calculation, and moving between two poses is a tween over those angles.

const UPPER_LENGTH := 1.7
const FOREARM_LENGTH := 1.7
const SHOULDER_HEIGHT := 1.0

var _turret: Node3D
var _shoulder: Node3D
var _elbow: Node3D
var _gripper: Node3D
var _tween: Tween = null
# The current pose: turret yaw, shoulder elevation, elbow bend (radians).
var _pose := Vector3(0.0, 0.8, -1.2)


## The gripper: put the carried box here (its origin is the top centre of the box).
var gripper: Node3D:
	get:
		return _gripper


func _ready() -> void:
	var paint := ApartmentKit.material(Color(0.95, 0.55, 0.1))
	var dark := ApartmentKit.material(Color(0.2, 0.2, 0.24))
	# The fixed base.
	var base := MeshInstance3D.new()
	var base_mesh := CylinderMesh.new()
	base_mesh.top_radius = 0.45
	base_mesh.bottom_radius = 0.55
	base_mesh.height = 0.6
	base_mesh.material = dark
	base.mesh = base_mesh
	base.position.y = 0.3
	add_child(base)
	var base_body := StaticBody3D.new()
	var base_shape := CollisionShape3D.new()
	var base_box := CylinderShape3D.new()
	base_box.radius = 0.55
	base_box.height = 0.8
	base_shape.shape = base_box
	base_shape.position.y = 0.4
	base_body.add_child(base_shape)
	add_child(base_body)
	# The turret turns about Y; the shoulder and elbow bend about X.
	_turret = Node3D.new()
	_turret.position.y = 0.6
	add_child(_turret)
	var column := _part(Vector3(0.5, SHOULDER_HEIGHT - 0.6, 0.5), paint)
	column.position.y = (SHOULDER_HEIGHT - 0.6) / 2.0
	_turret.add_child(column)
	_shoulder = Node3D.new()
	_shoulder.position.y = SHOULDER_HEIGHT - 0.6
	_turret.add_child(_shoulder)
	var upper := _part(Vector3(0.22, 0.22, UPPER_LENGTH), paint)
	upper.position.z = -UPPER_LENGTH / 2.0
	_shoulder.add_child(upper)
	_elbow = Node3D.new()
	_elbow.position.z = -UPPER_LENGTH
	_shoulder.add_child(_elbow)
	var joint := _part(Vector3(0.34, 0.34, 0.34), dark)
	_elbow.add_child(joint)
	var forearm := _part(Vector3(0.18, 0.18, FOREARM_LENGTH), paint)
	forearm.position.z = -FOREARM_LENGTH / 2.0
	_elbow.add_child(forearm)
	_gripper = Node3D.new()
	_gripper.position.z = -FOREARM_LENGTH
	_elbow.add_child(_gripper)
	var claw := _part(Vector3(0.5, 0.1, 0.5), dark)
	claw.position.y = 0.05
	_gripper.add_child(claw)
	_apply(_pose)


func _part(size: Vector3, material: Material) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mesh.material = material
	instance.mesh = mesh
	return instance


## Sets the joints: yaw of the turret, elevation of the upper arm and the bend of the elbow.
func _apply(pose: Vector3) -> void:
	_pose = pose
	_turret.rotation.y = pose.x
	_shoulder.rotation.x = pose.y
	_elbow.rotation.x = pose.z
	# The claw always hangs flat: undo the two bends.
	_gripper.rotation.x = -(pose.y + pose.z)


## The joint angles that put the gripper at `point` (a world position).
func pose_for(point: Vector3) -> Vector3:
	var local := to_local(point)
	var yaw := atan2(-local.x, -local.z)  # the arm points along -Z
	var distance := Vector2(local.x, local.z).length()
	var height := local.y - (0.6 + SHOULDER_HEIGHT - 0.6)
	var r := clampf(sqrt(distance * distance + height * height), absf(UPPER_LENGTH - FOREARM_LENGTH) + 0.1, UPPER_LENGTH + FOREARM_LENGTH - 0.05)
	var aim := atan2(height, distance)
	var cos_b := clampf((UPPER_LENGTH * UPPER_LENGTH + r * r - FOREARM_LENGTH * FOREARM_LENGTH) / (2.0 * UPPER_LENGTH * r), -1.0, 1.0)
	var shoulder := aim + acos(cos_b)
	var cos_c := clampf((UPPER_LENGTH * UPPER_LENGTH + FOREARM_LENGTH * FOREARM_LENGTH - r * r) / (2.0 * UPPER_LENGTH * FOREARM_LENGTH), -1.0, 1.0)
	var elbow := -(PI - acos(cos_c))
	return Vector3(yaw, shoulder, elbow)


## Moves the gripper to `point` over `seconds` (a coroutine: await it).
func reach_to(point: Vector3, seconds: float) -> void:
	var from := _pose
	var to := pose_for(point)
	# Turn the short way round.
	to.x = from.x + angle_difference(from.x, to.x)
	if _tween != null:
		_tween.kill()
	_tween = create_tween().set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	_tween.tween_method(func(t: float) -> void: _apply(from.lerp(to, t)), 0.0, 1.0, seconds)
	await _tween.finished
