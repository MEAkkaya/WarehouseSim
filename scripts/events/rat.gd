class_name Rat
extends Node3D
## A giant rat (placeholder shape). It scurries about the work floor, and when it
## finds a box lying open on the ground with something inside, it steals an item.
## The player must refill the box. Rats keep away from the player.

const AREA := WarehouseLayout.WORK_FLOOR  # x, z of the work floor

var speed: float = 3.2

var _target: Vector3 = Vector3.ZERO
var _box: Box = null
var _steal_time: float = 0.0
var _cooldown: float = 0.0
var _flee_left: float = 0.0
var _player: Player = null


func _ready() -> void:
	_player = get_tree().get_first_node_in_group("players") as Player
	var body := MeshInstance3D.new()
	var mesh := CapsuleMesh.new()
	mesh.radius = 0.28
	mesh.height = 1.1
	var material := StandardMaterial3D.new()
	material.albedo_color = Color(0.32, 0.28, 0.27)
	mesh.material = material
	body.mesh = mesh
	body.rotation.x = PI / 2.0  # lying along the walking direction (-Z)
	body.position.y = 0.3
	add_child(body)
	var tail := MeshInstance3D.new()
	var tail_mesh := BoxMesh.new()
	tail_mesh.size = Vector3(0.05, 0.05, 0.7)
	tail.mesh = tail_mesh
	tail.position = Vector3(0, 0.25, 0.8)
	add_child(tail)
	_pick_wander_target()


func _process(delta: float) -> void:
	_cooldown = maxf(0.0, _cooldown - delta)
	# Run away from the player when they get close.
	if _player != null and global_position.distance_to(_player.global_position) < 2.5:
		_flee_left = 1.2
	if _flee_left > 0.0:
		_flee_left -= delta
		var away := global_position - _player.global_position
		away.y = 0.0
		_move_towards(global_position + away.normalized() * 3.0, speed * 1.6, delta)
		return
	if _box == null and _cooldown <= 0.0:
		_box = _find_box()
	if _box != null:
		if not _is_stealable(_box):
			_box = null
			_steal_time = 0.0
			return
		var spot := _box.global_position
		if _move_towards(spot, speed, delta) < 1.0:
			_steal_time += delta
			if _steal_time > 1.5:
				_steal(_box)
				_box = null
				_steal_time = 0.0
				_cooldown = 8.0
		return
	if _move_towards(_target, speed * 0.6, delta) < 0.4:
		_pick_wander_target()


func _pick_wander_target() -> void:
	_target = Vector3(randf_range(AREA.position.x, AREA.end.x), 0.1, randf_range(AREA.position.y, AREA.end.y))


## An open box lying on the ground with something in it.
func _is_stealable(box: Box) -> bool:
	return is_instance_valid(box) and box.is_open and not box.contents.is_empty() \
			and box.placed_on == null and box.global_position.y < 1.0 \
			and AREA.grow(1.0).has_point(Vector2(box.global_position.x, box.global_position.z))


func _find_box() -> Box:
	var best: Box = null
	var best_distance := INF
	for node in get_tree().get_nodes_in_group("boxes"):
		var box := node as Box
		if _is_stealable(box) and box.get_parent() == get_parent():
			var distance := global_position.distance_to(box.global_position)
			if distance < best_distance:
				best = box
				best_distance = distance
	return best


func _steal(box: Box) -> void:
	var item := box.remove_item_at(randi() % box.contents.size())
	if item != null:
		GameState.notice.emit("A giant rat stole a %s from your box!" % item.display_name)
		_flee_left = 2.0


## Walks towards `target` (flat) and returns the remaining distance.
func _move_towards(target: Vector3, move_speed: float, delta: float) -> float:
	var to := Vector3(target.x - global_position.x, 0.0, target.z - global_position.z)
	var distance := to.length()
	if distance > 0.05:
		var step := minf(move_speed * delta, distance)
		var next := global_position + to.normalized() * step
		next.x = clampf(next.x, AREA.position.x - 1.0, AREA.end.x + 1.0)
		next.z = clampf(next.z, AREA.position.y - 1.0, AREA.end.y + 1.0)
		global_position = next
		rotation.y = lerp_angle(rotation.y, atan2(-to.x, -to.z), clampf(10.0 * delta, 0.0, 1.0))
	return distance
